---
title: "Homework assignment"
output: 
  html_document: 
    keep_md: yes
---



## Contents 

This document contains a description of the assignment solution, which generates the given target image by combining 31 multispectral images.

The repository also contains the relevant R code ("assignment_code.R") and a folder with the input images ("Data").

## Description of solution

### The data

The input data consists of 31 grayscale images with dimensions [512,512,1] (or [512,512,3] where RGB have equal values). The first two dimensions are x,y-coordinates of the pixel and the third is color intensity. The target image is of size [512,512,3], where the third dimension contains RGB values.

Each input image has a known wavelength between 400 and 700 nm, which is converted to a [1,3] vector of RGB values via an algorithm from <https://stackoverflow.com/questions/3407942/rgb-values-of-visible-spectrum>. In this assignment we use RGB values between 0-1 for computational purposes. They can be transformed into 0-255 range by simply multiplying by 255.

### Transformations 

Since we will be treating each image as a feature in the input data and the target image as a single target variable, we need to transform the inputs and target image into compatible shapes. 

First, we load each input image as a [512,512,1] array and melt it into a [262144,1] column, where each row represents a pixel and each pixel has color intensity with values between 0-1. Then, to color the image according to its wavelength, we multiply the column by the corresponding [1,3] RGB vector, ending up with a [262144,3] dataframe.  

For example, image 20 had wavelength 590, which is represented by RGB values R=0.972, G=0.762, B=0.000 (or R=248, G=194, B=0 on 0-255 scale). Multiplying its intensity with each color, we eliminate blue from the image and are left with a yellowish hue. 

![Original](Other\img20.png)![Colored](Other\img20_col.png)



```r
summary(cars)
```

```
##      speed           dist       
##  Min.   : 4.0   Min.   :  2.00  
##  1st Qu.:12.0   1st Qu.: 26.00  
##  Median :15.0   Median : 36.00  
##  Mean   :15.4   Mean   : 42.98  
##  3rd Qu.:19.0   3rd Qu.: 56.00  
##  Max.   :25.0   Max.   :120.00
```

## Including Plots

You can also embed plots, for example:

![](README_files/figure-html/pressure-1.png)<!-- -->

Note that the `echo = FALSE` parameter was added to the code chunk to prevent printing of the R code that generated the plot.
