jobs<-fread("cascades_Q1_jobs.txt",fill=TRUE,data.table = FALSE)
jobs<-jobs[-1,]
jobs$NCPUS<-as.integer(jobs$NCPUS)
jobs<- jobs[!is.na(jobs$NCPUS),]
jobs$Start<-ymd_hms(jobs$Start)
jobs$End<-ymd_hms(jobs$End)
jobs$job_seconds<-seconds(jobs$Start %--% jobs$End)
jobs$coreseconds<-jobs$job_seconds@.Data*jobs$NCPUS
jobs$corehours<-jobs$coreseconds/60/60
jobs$month<-month(jobs$Start)
jobs_filtered<-jobs[!is.na(jobs$corehours),]
job_summary_month_user <- summaryBy(corehours~User+month,data=jobs_filtered)
job_summary_month_account <- summaryBy(corehours~Account+month,data=jobs_filtered,FUN=sum)
