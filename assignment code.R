library(png)
library(bmp)
library(reshape)
library(dplyr)
library(tidyverse)

# input image wavelengths
colors <- seq(400,700,10) 

# wavelength to RGB [0,1] conversion function from https://stackoverflow.com/questions/3407942/rgb-values-of-visible-spectrum
spectral_color <- function(l) {
  r=0;   g=0;   b=0
  if ((l>=400.0)&(l<410.0)) { t=(l-400.0)/(410.0-400.0); r=    +(0.33*t)-(0.20*t*t) }
  else if ((l>=410.0)&(l<475.0)) { t=(l-410.0)/(475.0-410.0); r=0.14         -(0.13*t*t) }
  else if ((l>=545.0)&(l<595.0)) { t=(l-545.0)/(595.0-545.0); r=    +(1.98*t)-(     t*t) }
  else if ((l>=595.0)&(l<650.0)) { t=(l-595.0)/(650.0-595.0); r=0.98+(0.06*t)-(0.40*t*t); }
  else if ((l>=650.0)&(l<700.0)) { t=(l-650.0)/(700.0-650.0); r=0.65-(0.84*t)+(0.20*t*t); }
  if ((l>=415.0)&(l<475.0)) { t=(l-415.0)/(475.0-415.0); g=             +(0.80*t*t); }
  else if ((l>=475.0)&(l<590.0)) { t=(l-475.0)/(590.0-475.0); g=0.8 +(0.76*t)-(0.80*t*t); }
  else if ((l>=585.0)&(l<639.0)) { t=(l-585.0)/(639.0-585.0); g=0.84-(0.84*t)           ; }
  if ((l>=400.0)&(l<475.0)) { t=(l-400.0)/(475.0-400.0); b=    +(2.20*t)-(1.50*t*t); }
  else if ((l>=475.0)&(l<560.0)) { t=(l-475.0)/(560.0-475.0); b=0.7 -(     t)+(0.30*t*t); }
  
  return(c(r,g,b))
}

# ID dataframe to transform image data into long format
input <- merge(seq(1:512), seq(1:512)) %>% merge(.,c('R','G','B'),by = NULL)
colnames(input) <- c('x','y','RGB')

# load input images
path <- "~\\assignment\\Data\\"

for (i in 1:31) {
  # read image colors between [0,1], transform into long format for matrix multiplication
  img <- readPNG(paste0(path, "multispectral_images\\sponges_ms_", ifelse(i<10,0,""),i, ".png"))
  img1 <- as.matrix(melt(img))
  
  # get RGB values for image wavelength
  rgb <-  t(as.matrix(spectral_color(colors[i]))) 
  
  # multiply each pixel color with RGB vector (best guess, but seems to work)
  rgbimg <- data.frame(img1[,1:2],img1[,3] %*% rgb) %>% melt(., id=c("X1","X2"))
 
  # add each image data as new column in data frame
  input[[paste0("img_",i)]] <- rgbimg[,4]
}

# get target image in fancy RGB
target <- read.bmp(paste0(path,"sponges_RGB.bmp")) #returns y,x,RGB
tarimg <- as.raster(target, max = 255)
plot(1:512, type='n')
rasterImage(tarimg,1,1,512,512)

# put target into long format, standardize 0-255 RGB values into 0-1 to make it compatible with input images
target1 <- melt(target) 
target <- target1$value/255

#input data, remove location indices, first and last images since those have RGB=0
df <- input %>% select(-x, -y, -img_1, -img_31) 


# Linear regression, R2 = 0.9597

model1 <- lm(target ~ ., df)
summary(model1)   

# predict target image based on input, turn negatives into 0 and 1+ values into 1
pred <- predict(model1, df) %>% replace(., .<0, 0) %>% replace(., .>1, 1) 

# make a 3D array for rastering
dim(pred) <- c(512,512,3)
rasterImage(pred,1,1,512,512)     # prediction (linear regression)
rasterImage(tarimg ,1,1,512,512)  # actual


# CatBoost, R2 = 0.9997

# install.packages('devtools')
# devtools::install_url('https://github.com/catboost/catboost/releases/download/v0.22/catboost-R-Windows-0.22.tgz', INSTALL_opts = c("--no-multiarch"))
library(catboost)

# create pools for training and prediction
train_pool <- catboost.load_pool(data = df, cat_features=1, label = target)
real_pool <-  catboost.load_pool(data = df, cat_features=1, label = NULL)

# train model, takes about 1 minute on laptop
model2 <- catboost.train(train_pool,  NULL,
                        params = list(loss_function = 'RMSE', iterations = 200, 
                        metric_period=10, random_seed=0, eval_metric='R2'))

# predict target image based on input, turn negatives into 0 and 1+ values into 1
pred2 <- catboost.predict(model2, real_pool)
pred2 <- pred2 %>% replace(., .<0, 0) %>% replace(., .>1, 1) 

# make a 3D array for rastering
dim(pred2) <- c(512,512,3)
rasterImage(pred2,1,1,512,512)    # prediction (CatBoost)
rasterImage(tarimg ,1,1,512,512)  # actual
