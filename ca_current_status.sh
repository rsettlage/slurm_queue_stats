#!/bin/bash

echo get stats from Cascades
## get any reserved nodes
sinfo -T > ~/quick_start/ca_reserved.txt

## get queue list
sinfo -s > ~/quick_start/ca_queues.txt

## get list of free cores
#{ for NN in $(sinfo -N -r -h -o "%N" | uniq); do sinfo -n $NN -h -o "%N %C" | cut -f 1,2 -d "/"; done; } > ~/quick_start/ca_available.txt

## get list of free gpus
for NN in $(sinfo -N -r -h -o "%N" | uniq); do scontrol show node $NN --oneliner; done | sed 's/[,=]/\t/g' | awk 'BEGIN{ORS=""}{for(i=1; i < NF; i++){if($i~/NodeName/) {print ""$(i+1)" "};if($i~/CPUAlloc/) {print "CPUAlloc= "$(i+1)" "};if($i~/CPUTot/) {print "CPUTot= "$(i+1)" "};if($i~/gres[/]gpu/){print "available/allocated gres/gpu= " $(i+1)" "}};print "\n"}' | awk '{ if(NF==8){$0=$0"available/allocated gres/gpu= 0"};print }' > ~/quick_start/ca_available_gpu.txt

## start to get some wait time measures
squeue | grep "Limit\|Time" | grep -v "PartitionTimeLimit" | awk '{ print $1,$8,"cascades" }' > ~/quick_start/ca_metered_jobs.txt
sacct --cluster=cascades --start=$(date -d "-12hours" +"%m/%d/%y-%H:%M") --end=$(date +"%m/%d/%y-%H:%M") --state=R -X -a -o JobID,Submit,Start,Eligible,Partition,Reservation,AllocNodes,AllocCPUS,ReqNodes,ReqCPUS,ReqGRES,Timelimit,Elapsed | awk '{ print $0,"cascades"}' > ~/quick_start/ca_finished_jobs.txt
##sacct --cluster=dragonstooth -n -j 236760 -X -o JobID,Submit,Start,Eligible,Partition,Reservation,AllocNodes,AllocCPUS,ReqNodes,ReqCPUS,Timelimit,Elapsed

echo "finished getting status from" $(hostname)
exit;
