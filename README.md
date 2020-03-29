---
title: "Homework assignment"
output: 
  html_document: 
    keep_md: yes
---

## Contents 

This document contains a description of the assignment solution, which generates the given target image by combining 31 multispectral images.

The repository also contains the relevant R code ([assignment_code.R](assignment%20code.R)) and a folder with the input images ([Data/](Data)).


## Description of solution

### 1. The data

The input data consists of 31 grayscale images with dimensions [512,512,1] (or [512,512,3] where RGB have equal values). The first two dimensions are x,y-coordinates of the pixel and the third is color intensity. The target image is of size [512,512,3], where the third dimension contains RGB values.

Target image:

<img src="Data/sponges_RGB.bmp" width=300 />

Each input image has a known wavelength between 400 and 700 nm, which is converted to a [1,3] vector of RGB values via an algorithm from <https://stackoverflow.com/questions/3407942/rgb-values-of-visible-spectrum>. In this assignment we use RGB values between 0-1 for computational purposes. They can be transformed into 0-255 range by simply multiplying by 255.


```r
require(png)
require(bmp)
require(reshape)
require(dplyr)
require(tidyverse)

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
```


### 2. Transformations 

Since we will be treating each image as a feature in the input data and the target image as a single target variable, we need to transform the inputs and target image into compatible shapes. 

First, we load each input image as a [512,512,1] array and melt it into a [262144,1] column, where each row represents a pixel and each pixel has color intensity with values between 0-1. Then, to color the image according to its wavelength, we multiply the column by the corresponding [1,3] RGB vector, ending up with a [262144,3] dataframe.  

For example, image 20 had wavelength 590, which is represented by RGB values R=0.972, G=0.762, B=0.000 (or R=248, G=194, B=0 on 0-255 scale). Multiplying its intensity with each color, we eliminate blue from the image, decrease the red and green, and are left with a yellowish hue. 


```r
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
```

Image 20, original and reconstructed after colouring:

![](Other/img20.png) ![](Other/img20_col.png)

In order to get a single feature from each image, we now melt each [262144,3] dataframe into a [786432,1] column and append all resulting columns horizontally. This leaves us with an input dataframe of size [786432,31], not including pixel coordinates and the R/G/B factor. The target image is also melted from [512,512,3] into [786432,1].


```r
# get target image in RGB
target <- read.bmp(paste0(path,"sponges_RGB.bmp")) #returns y,x,RGB
tarimg <- as.raster(target, max = 255)

# put target into long format, standardize 0-255 RGB values into 0-1 to make it compatible with input images
target1 <- melt(target) 
target <- target1$value/255

#input data, remove location indices, first and last images since those have RGB=0
df <- input %>% select(-x, -y, -img_1, -img_31) 
```

Now we need to find a combination of the input features that is close to the target variable.


### 3. Models

#### 3.1 Linear regression

As the target feature is a continuous variable, it is reasonable to try linear regression first to set a baseline. 


```r
model1 <- lm(target ~ ., df)
summary(model1) 
```

```
## 
## Call:
## lm(formula = target ~ ., data = df)
## 
## Residuals:
##      Min       1Q   Median       3Q      Max 
## -0.51527 -0.03262  0.00480  0.03004  0.52705 
## 
## Coefficients:
##               Estimate Std. Error  t value Pr(>|t|)    
## (Intercept)  1.830e-01  2.396e-04  763.766  < 2e-16 ***
## RGBG        -5.228e-02  2.998e-04 -174.382  < 2e-16 ***
## RGBR        -1.140e-01  2.999e-04 -380.110  < 2e-16 ***
## img_2        1.437e+00  2.099e-02   68.480  < 2e-16 ***
## img_3       -8.714e-01  2.971e-02  -29.332  < 2e-16 ***
## img_4        5.625e-01  3.423e-02   16.434  < 2e-16 ***
## img_5       -1.140e+00  3.774e-02  -30.212  < 2e-16 ***
## img_6        2.094e+00  4.046e-02   51.757  < 2e-16 ***
## img_7       -4.742e-01  3.730e-02  -12.713  < 2e-16 ***
## img_8        1.254e+00  3.055e-02   41.040  < 2e-16 ***
## img_9       -3.784e+00  2.902e-02 -130.395  < 2e-16 ***
## img_10       5.086e+00  2.394e-02  212.458  < 2e-16 ***
## img_11       1.410e+00  2.307e-02   61.126  < 2e-16 ***
## img_12      -6.041e+00  2.808e-02 -215.163  < 2e-16 ***
## img_13      -1.354e+00  3.348e-02  -40.448  < 2e-16 ***
## img_14       3.965e+00  4.114e-02   96.380  < 2e-16 ***
## img_15       9.497e+00  3.573e-02  265.825  < 2e-16 ***
## img_16      -1.399e+01  3.703e-02 -377.829  < 2e-16 ***
## img_17       5.115e+00  3.016e-02  169.570  < 2e-16 ***
## img_18       5.062e-01  2.539e-02   19.941  < 2e-16 ***
## img_19       1.686e-01  2.702e-02    6.239  4.4e-10 ***
## img_20      -8.036e-01  2.866e-02  -28.039  < 2e-16 ***
## img_21       4.725e-01  3.218e-02   14.684  < 2e-16 ***
## img_22      -4.278e-01  3.811e-02  -11.226  < 2e-16 ***
## img_23      -1.913e+00  3.800e-02  -50.325  < 2e-16 ***
## img_24       4.494e+00  4.277e-02  105.069  < 2e-16 ***
## img_25       7.355e+00  3.611e-02  203.715  < 2e-16 ***
## img_26      -2.081e+00  6.628e-02  -31.391  < 2e-16 ***
## img_27      -1.132e+01  7.301e-02 -155.069  < 2e-16 ***
## img_28      -4.189e+00  1.131e-01  -37.051  < 2e-16 ***
## img_29       3.355e+00  1.904e-01   17.622  < 2e-16 ***
## img_30       1.436e+01  2.409e-01   59.623  < 2e-16 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## Residual standard error: 0.0547 on 786400 degrees of freedom
## Multiple R-squared:  0.9597,	Adjusted R-squared:  0.9597 
## F-statistic: 6.036e+05 on 31 and 786400 DF,  p-value: < 2.2e-16
```

R2=0.9597, which is not bad, all the variables are statistically significant as well.
We predict new labels based on the model and replace values outside of 0-1 range with 0 or 1 as needed.


```r
# predict target image based on input, turn negatives into 0 and 1+ values into 1
pred <- predict(model1, df) %>% replace(., .<0, 0) %>% replace(., .>1, 1) 

# make a 3D array for rastering
dim(pred) <- c(512,512,3)
plot(1:512, type='n')
rasterImage(pred,1,1,512,512)     # prediction (linear regression)
rasterImage(tarimg ,1,1,512,512)  # actual
```
Predicted image (left) and actual target (right):

![](Other/linreg.png) ![](Other/target.png)

It is a reasonable result, but we can do better.


#### 3.2 CatBoost

[CatBoost](https://catboost.ai/) is a gradient boosting library from the people who brought us Yandex. It is not available on CRAN, but it can easily be installed directly from source. 


```r
# install.packages('devtools')
# devtools::install_url('https://github.com/catboost/catboost/releases/download/v0.22/catboost-R-Windows-0.22.tgz', INSTALL_opts = c("--no-multiarch"))
library(catboost)
```
For CatBoost, we need to create pools, which are objects that hold input data. We use a simple model with RMSE loss function, 200 iterations and R2 output to make it comparable to linear regression output.



```r
# create pools for training and prediction
train_pool <- catboost.load_pool(data = df, cat_features=1, label = target)
real_pool <-  catboost.load_pool(data = df, cat_features=1, label = NULL)

# train model, takes about 1 minute on laptop
model2 <- catboost.train(train_pool,  NULL,
                        params = list(loss_function = 'RMSE', iterations = 200, 
                        metric_period=10, random_seed=0, eval_metric='R2'))
```

```
## Learning rate set to 0.434556
## 0:	learn: 0.6353386	total: 697ms	remaining: 2m 18s
## 10:	learn: 0.9933522	total: 4.55s	remaining: 1m 18s
## 20:	learn: 0.9968976	total: 8.42s	remaining: 1m 11s
## 30:	learn: 0.9979444	total: 12.6s	remaining: 1m 8s
## 40:	learn: 0.9984123	total: 15.4s	remaining: 59.6s
## 50:	learn: 0.9987446	total: 19.3s	remaining: 56.3s
## 60:	learn: 0.9989681	total: 23s	remaining: 52.3s
## 70:	learn: 0.9991077	total: 26.3s	remaining: 47.7s
## 80:	learn: 0.9992286	total: 30.4s	remaining: 44.6s
## 90:	learn: 0.9993305	total: 33.9s	remaining: 40.6s
## 100:	learn: 0.9994011	total: 37.4s	remaining: 36.7s
## 110:	learn: 0.9994593	total: 41.9s	remaining: 33.6s
## 120:	learn: 0.9995041	total: 46.2s	remaining: 30.2s
## 130:	learn: 0.9995412	total: 50.4s	remaining: 26.6s
## 140:	learn: 0.9995735	total: 54.5s	remaining: 22.8s
## 150:	learn: 0.9996007	total: 58.5s	remaining: 19s
## 160:	learn: 0.9996248	total: 1m 2s	remaining: 15s
## 170:	learn: 0.9996456	total: 1m 5s	remaining: 11.2s
## 180:	learn: 0.9996660	total: 1m 9s	remaining: 7.29s
## 190:	learn: 0.9996815	total: 1m 13s	remaining: 3.48s
## 199:	learn: 0.9996989	total: 1m 17s	remaining: 0us
```

```r
# predict target image based on input, turn negatives into 0 and 1+ values into 1
pred2 <- catboost.predict(model2, real_pool)
pred2 <- pred2 %>% replace(., .<0, 0) %>% replace(., .>1, 1) 

# make a 3D array for rastering
dim(pred2) <- c(512,512,3)
plot(1:512, type='n')
rasterImage(pred2,1,1,512,512)    # prediction (CatBoost)
rasterImage(tarimg ,1,1,512,512)  # actual
```
R2=0.9997, which is a much better result. Comparing the predicted image and the target visually, it is almost impossible to notice any differences.
Predicted image (left) and actual target (right):

![](Other/cb.png) ![](Other/target.png)



