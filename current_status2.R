
suppressMessages(library(kableExtra))
suppressMessages(library(data.table))
suppressMessages(library(dplyr))
suppressMessages(library(tidyr))

## being overly commenty to make explicit -- 
## here is how the data was created on each cluster
##
## for NN in $(sinfo -N -r -h -o "%N" | uniq); do scontrol show node $NN --oneliner; done | \
## sed 's/[,=]/\t/g' | \
## awk 'BEGIN{ORS=""}{for(i=1; i < NF; i++){if($i~/NodeName/) {print ""$(i+1)" "}; \
##      if($i~/CPUAlloc/) {print "CPUAlloc= "$(i+1)" "};if($i~/CPUTot/) {print "CPUTot= "$(i+1)" "}; \
##      if($i~/gres[/]gpu/){print "available/allocated gres/gpu= " $(i+1)" "}};print "\n"}' | \
## awk '{ if(NF==8){$0=$0"available/allocated gres/gpu= 0"};print }'

######################################
## read in all data and tag it with source cluster
######################################

## queues we are interested in
general_queues <- fread("./queues_to_report.txt",header=FALSE)
## queue vs node list
ca_queues <- fread("sed 's_/_ _' ./ca_queues.txt",sep=" ",select=c(1,6),data.table=FALSE)
dt_queues <- fread("sed 's_/_ _' ./dt_queues.txt",sep=" ",select=c(1,6),data.table=FALSE)
hu_queues <- fread("sed 's_/_ _' ./hu_queues.txt",sep=" ",select=c(1,6),data.table=FALSE)
all_queues <- rbind(ca_queues,dt_queues,hu_queues)
all_queues$machine <- ifelse(grepl("ca",all_queues$NODELIST),"ca","dt")
all_queues$machine <- ifelse(grepl("hu",all_queues$NODELIST),"hu",all_queues$machine)

## core status
all_available <- fread("cat ca_available_gpu.txt dt_available_gpu.txt hu_available_gpu.txt",header=FALSE,sep=" ",
                        data.table=FALSE,fill=TRUE,select=c(1,3,5,8,11),
                       col.names=c("node","used","total","gpu.total","gpu.used"))
all_available$machine <- ifelse(grepl("ca",all_available$node),"ca","dt")
all_available$machine <- ifelse(grepl("hu",all_available$node),"hu",all_available$machine)

## reservations
all_reservation <- fread("cat ./ca_reserved.txt ./dt_reserved.txt ./hu_reserved.txt | sed '/No reservations in the system/d' ",data.table=FALSE)
all_reservation$machine <- ifelse(grepl("ca",all_reservation$NODELIST),"ca","dt")
all_reservation$machine <- ifelse(grepl("hu",all_reservation$NODELIST),"hu",all_reservation$machine)

######################################
# clean and munge data
######################################

## calculate necessary columns for cores and gpus: free, used, total
all_available$free <- all_available$total - all_available$used
all_available$gpu.free <- all_available$gpu.total - all_available$gpu.used

## remove reserved nodes from ranges, only care about "ACTIVE", remove extra rows
all_reservation <- all_reservation[all_reservation$RESV_NAME != "RESV_NAME",]
all_reservation <- all_reservation[all_reservation$STATE != "INACTIVE",c(1,ncol(all_reservation)-1,ncol(all_reservation))]

## get rid of *
all_queues$PARTITION <- gsub("*","",all_queues$PARTITION,fixed=TRUE)
## limit to queues we care about
all_queues <- all_queues[all_queues$PARTITION %in% general_queues$V1,]

## get rid of special characters
if(nrow(all_queues)){
    all_queues$NODELIST <- gsub("ca|dt|hu|\\]|\\[","",all_queues$NODELIST,perl=TRUE)
}
if(nrow(all_reservation)){
    all_reservation$NODELIST <- gsub("ca|dt|hu|\\]|\\[","",all_reservation$NODELIST,perl=TRUE)
}

## convert NODELIST to list of nodes
str_eval=function(x) {return(eval(parse(text=x)))} #helper function
for(j in 1:nrow(all_queues)){
    if(!is.na(all_queues$NODELIST[j])){
        temp <- unlist(strsplit(all_queues$NODELIST[j],","))
        for(i in 1:length(temp)){
            if(grepl("-",temp[i])){
                temp[i] <- gsub("-",":",temp[i])
                temp[i] <- paste(sprintf("%03d",str_eval(temp[i])),sep="",collapse=",")
            }
        }
        all_queues$NODELIST[j] <- paste(all_queues$machine[j],paste(temp,collapse=","),sep="",collaps="")
        all_queues$NODELIST[j] <- gsub(",",paste0(",",all_queues$machine[j]),all_queues$NODELIST[j])
        all_queues$NODELIST[j] <- gsub(",NA","",all_queues$NODELIST[j])
    }
}
all_queues <- all_queues[,c(1,3,2)]

## ditto for reservations, convert node range to number range for easier handling
## just keeping list of reserved nodes, don't care about why if users cant use them
for(j in 1:nrow(all_reservation)){
    if(!is.na(all_reservation$NODELIST[j])){
        temp <- unlist(strsplit(all_reservation$NODELIST[j],","))
        for(i in 1:length(temp)){
            if(grepl("-",temp[i])){
                temp[i] <- gsub("-",":",temp[i])
                temp[i] <- paste(sprintf("%03d",str_eval(temp[i])),sep="",collapse=",")
            }
        }
        all_reservation$NODELIST[j] <- paste(all_reservation$machine[j],paste(temp,collapse=","),sep="",collaps="")
        all_reservation$NODELIST[j] <- gsub(",",paste0(",",all_reservation$machine[j]),all_reservation$NODELIST[j])
        all_reservation$NODELIST[j] <- gsub(",NA","",all_reservation$NODELIST[j])
    }
}
all_reservation <- unlist(strsplit(all_reservation$NODELIST,","))


# flag nodes as reserved
all_available$reserved <- ifelse(all_available$node %in% all_reservation,1,0)

######################################
# summarize data
######################################

## summary by queue
## all_available
## all_queues
queue_list <- all_queues$PARTITION[!duplicated(all_queues$PARTITION)]
for(i in 1:length(queue_list)){
    tempnames <- c(colnames(all_available),queue_list[i])
    temp_nodes <- unlist(strsplit(all_queues$NODELIST[all_queues$PARTITION %in% queue_list[i]],","))
    all_available$i <- ifelse(all_available$node %in% temp_nodes,1,0)
    colnames(all_available) <- tempnames
}

ca_summary <- as.data.frame(matrix(0,nrow=9,ncol=length(all_queues$PARTITION)))
colnames(ca_summary) <- all_queues$PARTITION
rownames(ca_summary) <- c("total cores/node","total gpus/node","nodes in partition","reserved/down nodes","cores available","gpus available","1/2 nodes available","full nodes available","%utilization cores/nodes")

dt_summary <- as.data.frame(matrix(0,nrow=7,ncol=length(all_queues$PARTITION)))
colnames(dt_summary) <- all_queues$PARTITION
rownames(dt_summary) <- c("total cores/node","nodes in partition","reserved/down nodes","cores available","1/2 nodes available","full nodes available","%utilization cores/nodes")

hu_summary <- as.data.frame(matrix(0,nrow=9,ncol=length(all_queues$PARTITION)))
colnames(hu_summary) <- all_queues$PARTITION
rownames(hu_summary) <- c("total cores/node","total gpus/node","nodes in partition","reserved/down nodes","cores available","gpus available","1/2 nodes available","full nodes available","%utilization cores/nodes")

## get core summary by queue
## get 1/2 node availability by queue
## get full node availability by queue

for(i in 1:ncol(ca_summary)){
    current_queue <- colnames(ca_summary)[i]
    nodes_in_queue <- all_queues$NODELIST[all_queues$machine=="ca" & all_queues$PARTITION==current_queue]
    nodes_in_queue <- unlist(strsplit(nodes_in_queue,","))
    queue_status <- all_available[all_available[,current_queue]==1 & all_available$machine=="ca",]
    if(nrow(queue_status)>0){
        ca_summary[1,i] <- max(queue_status$total)                              #"total cores/node"
        ca_summary[2,i] <- max(queue_status$gpu.total)                          #"total gpus/node"
        ca_summary[3,i] <- length(nodes_in_queue)                               #"nodes in partition"
        queue_status <- queue_status[queue_status$total==ca_summary[1,i],] ## get rid of junk nodes
        queue_status <- queue_status[queue_status$reserved == 0,] ## remove reserved nodes
        ca_summary[4,i] <- length(nodes_in_queue) - nrow(queue_status)          #"reserved/down nodes"
        ca_summary[5,i] <- sum(queue_status$free)                               #"cores available"
        ca_summary[6,i] <- sum(queue_status$gpu.free)                           #"gpus available"
        ca_summary[7,i] <- sum((queue_status$free>queue_status$used-1)*1)       #"1/2 nodes available"
        ca_summary[8,i] <- sum((queue_status$free==ca_summary[1,i])*1)          #"full nodes available"
        core_utilization <- round(100-sum(queue_status$free)*100/sum(queue_status$total),1)
        node_utilization <- round(100-sum((queue_status$free==ca_summary[1,i])*1)*100/nrow(queue_status),1)
        ca_summary[9,i] <- paste0(core_utilization,"/",node_utilization)        #"%utilization cores/nodes"
    }
}
ca_summary[is.na(ca_summary)] <- "-"
ca_summary <- ca_summary[,!duplicated(colnames(ca_summary))]
ca_summary <- select_if(ca_summary,ca_summary[1,]>0)

for(i in 1:ncol(dt_summary)){
    current_queue <- colnames(dt_summary)[i]
    nodes_in_queue <- all_queues$NODELIST[all_queues$machine=="dt" & all_queues$PARTITION==current_queue]
    nodes_in_queue <- unlist(strsplit(nodes_in_queue,","))
    queue_status <- all_available[all_available[,current_queue]==1 & all_available$machine=="dt",]
    if(nrow(queue_status)>0){
        dt_summary[1,i] <- max(queue_status$total)                              #"total cores/node"
        dt_summary[2,i] <- length(nodes_in_queue)                               #"nodes in partition"
        queue_status <- queue_status[queue_status$total==dt_summary[1,i],] ## get rid of junk nodes
        queue_status <- queue_status[queue_status$reserved == 0,] ## remove reserved nodes
        dt_summary[3,i] <- length(nodes_in_queue) - nrow(queue_status)          #"reserved/down nodes"
        dt_summary[4,i] <- sum(queue_status$free)                               #"cores available"
        dt_summary[5,i] <- sum((queue_status$free>queue_status$used-1)*1)       #"1/2 nodes available"
        dt_summary[6,i] <- sum((queue_status$free==dt_summary[1,i])*1)          #"full nodes available"
        core_utilization <- round(100-sum(queue_status$free)*100/sum(queue_status$total),1)
        node_utilization <- round(100-sum((queue_status$free==dt_summary[1,i])*1)*100/nrow(queue_status),1)
        dt_summary[7,i] <- paste0(core_utilization,"/",node_utilization)        #"%utilization cores/nodes"
    }
}
dt_summary[is.na(dt_summary)] <- "-"
dt_summary <- dt_summary[,!duplicated(colnames(dt_summary))] 
dt_summary <- select_if(dt_summary,dt_summary[1,]>0)

for(i in 1:ncol(hu_summary)){
    current_queue <- colnames(hu_summary)[i]
    nodes_in_queue <- all_queues$NODELIST[all_queues$machine=="hu" & all_queues$PARTITION==current_queue]
    nodes_in_queue <- unlist(strsplit(nodes_in_queue,","))
    queue_status <- all_available[all_available[,current_queue]==1 & all_available$machine=="hu",]
    if(nrow(queue_status)>0){
        hu_summary[1,i] <- max(queue_status$total)                              #"total cores/node"
        hu_summary[2,i] <- max(queue_status$gpu.total)                          #"total gpus/node"
        hu_summary[3,i] <- length(nodes_in_queue)                               #"nodes in partition"
        queue_status <- queue_status[queue_status$total==hu_summary[1,i],] ## get rid of junk nodes
        queue_status <- queue_status[queue_status$reserved == 0,] ## remove reserved nodes
        hu_summary[4,i] <- length(nodes_in_queue) - nrow(queue_status)          #"reserved/down nodes"
        hu_summary[5,i] <- sum(queue_status$free)                               #"cores available"
        hu_summary[6,i] <- sum(queue_status$gpu.free)                           #"gpus available"
        hu_summary[7,i] <- sum((queue_status$free>queue_status$used-1)*1)       #"1/2 nodes available"
        hu_summary[8,i] <- sum((queue_status$free==hu_summary[1,i])*1)          #"full nodes available"
        core_utilization <- round(100-sum(queue_status$free)*100/sum(queue_status$total),1)
        node_utilization <- round(100-sum((queue_status$free==hu_summary[1,i])*1)*100/nrow(queue_status),1)
        hu_summary[9,i] <- paste0(core_utilization,"/",node_utilization)        #"%utilization cores/nodes"
    }
}
hu_summary[is.na(hu_summary)] <- "-"
hu_summary <- hu_summary[,!duplicated(colnames(hu_summary))]
hu_summary <- select_if(hu_summary,hu_summary[1,]>0)

######################################
# make pretty tables
######################################

ca_table<-kable(ca_summary,format = "html", 
                caption = paste0("Cascades core and node availability at ",(format(Sys.time(), '%d %B, %Y -- %I:%M:%S%p')))) %>%
    kable_styling("striped",full_width = FALSE,position = "left")

dt_table<-kable(dt_summary,format = "html", 
                caption = paste0("Dragonstooth core and node availability at ",(format(Sys.time(), '%d %B, %Y -- %I:%M:%S%p')))) %>%
    kable_styling("striped",full_width = FALSE,position = "float_left")

hu_table<-kable(hu_summary,format = "html", 
                caption = paste0("Huckleberry core and node availability at ",(format(Sys.time(), '%d %B, %Y -- %I:%M:%S%p')))) %>%
    kable_styling("striped",full_width = FALSE,position = "float_right")

#save tables to file
sink("./cluster_stats.txt")
##capture.output(ca_table,"./cluster_stats.txt")
cat("<img src='https://raw.githubusercontent.com/rsettlage/slurm_queue_stats/master/all_data_combined_today.jpg' alt='today' width='900'/>\n")
cat("<img src='https://raw.githubusercontent.com/rsettlage/slurm_queue_stats/master/all_data_combined_month.jpg' alt='month' width='450'/>\n")
cat("<img src='https://raw.githubusercontent.com/rsettlage/slurm_queue_stats/master/all_data_combined_year.jpg' alt='year' width='450'/>\n")
print(ca_table)
print(dt_table)
print(hu_table)
cat("<img src='https://raw.githubusercontent.com/rsettlage/slurm_queue_stats/master/wait_time_plot_by_AllocCPU.jpg' alt='waittime' width='450'/>\n")
sink()

######################################
# add date stamp and save data
######################################

##get data into long format and cat all machines together
time_stamp <- format(Sys.time(), '%d-%B-%Y--%I:%M%P')
ca_final <- ca_summary %>% 
    mutate(metric=rownames(ca_summary)) %>% 
    gather(key="queue",value="value",-metric) %>%
    mutate(date=time_stamp, machine="cascades")

dt_final <- dt_summary %>% 
    mutate(metric=rownames(dt_summary)) %>% 
    gather(key="queue",value="value",-metric) %>%
    mutate(date=time_stamp, machine="dragonstooth")

hu_final <- hu_summary %>% 
    mutate(metric=rownames(hu_summary)) %>% 
    gather(key="queue",value="value",-metric) %>%
    mutate(date=time_stamp, machine="huckleberry")

all_final <- rbind(ca_final,dt_final,hu_final)

### save history
saveRDS(all_final,paste0("all_final_",time_stamp,".RDS"))



