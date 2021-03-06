#!/usr/bin/env Rscript

# Script for pre-processing and analysis of MTBLS1
# Created by Daniel Canueto

library(SOAP)
library(data.table)
library(speaq)
#library(ropls)

# dataset of Bruker-processed spectra read with nmrglue (CSV format)
dataset_path="/data/test_data_spectra.csv"
initial_dataset=fread(dataset_path,header=F,sep=',')

# ppm axis for each bin of the dataset read with nmrglue (CSV format)
ppm_path="/data/test_data_ppm.csv"
ppm=fread(ppm_path,header=F,sep=',')

# Path of folder created with Python script with Bruker-processed spectra
bruker_path="/data/MTBLS1"

#Adaptation of dataset to SOAP structure
initial_dataset=t(apply(initial_dataset,1,as.complex))
attributes(initial_dataset)$dimnames[[2]]=as.vector(t(ppm))

#The function InternalReferencing needs the 'FIDInfo' variable
fidList<-ReadFids(bruker_path,subdirs=T)
Fid<-fidList[["Fid_data"]]
Fidinfo<-fidList[["Fid_info"]]

#Referencing to TSP
pre_processed_dataset=InternalReferencing(initial_dataset,Fidinfo)
#Selection of edges of the window of spectrum with valuable information
pre_processed_dataset=WindowSelection ( pre_processed_dataset,from.ws = 0.2, to.ws = 9.3)
#Removal of regions of spectrum with not useful information that can worsen later pre-procesing steps
fromto=list(Glucose=c(3.19,3.99),Glucose2=c(5.21,5.27),Water =c(4.5, 5.1), Urea=c(5.5,6.1))
pre_processed_dataset=RegionRemoval(pre_processed_dataset,typeofspectra = "manual",fromto.rr=fromto)
#PQN noormalitzationof spectra. SOAP does not allow selection of spectra as reference. Workflow4metabolomics allows it.
pre_processed_dataset<-Normalization(pre_processed_dataset,type.norm='pqn')
#Setting of dataset structure for signal alignment with 'speaq' package
aligned_dataset=t(apply(pre_processed_dataset,1,as.numeric))
#Signal alignment with 'speaq' package 
peakList <- detectSpecPeaks(aligned_dataset,
  nDivRange = c(128),
  scales = seq(1, 16, 2),
  baselineThresh = quantile(aligned_dataset,0.60,na.rm=T),
  SNR.Th = -1,
  verbose=FALSE
);
resFindRef<- findRef(peakList);
refInd <- resFindRef$refInd;
maxShift = round(-0.025/mean(diff(as.numeric(colnames(pre_processed_dataset)))));
aligned_dataset <- dohCluster(aligned_dataset,
  peakList = peakList,
  refInd = refInd,
  maxShift = maxShift,
  acceptLostPeak = TRUE, verbose=FALSE);

#Bucketing of spectra to reduce dimensionality and reduce misalignments of signals
colnames(aligned_dataset)=colnames(pre_processed_dataset)
aligned_dataset = Bucketing(aligned_dataset,width=T,m=0.01)
#Variable to analyze in PLS: 48 first samples have diabetes, the others not. When you decide how the metadata is treated, this can change
variable=rep(c(1,2),times=c(48,84))
#PLS_DA of dataset with eman centering and pareto scaling.
PLS_DA_data <- opls(aligned_dataset, variable,scaleC='pareto')

