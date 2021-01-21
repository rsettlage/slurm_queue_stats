#!/bin/bash

####### job customization
#SBATCH --job-name=qstat
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 00:05:00
#SBATCH -p normal_q,dev_q
#SBATCH -A arctest
#SBATCH --mail-user=rsettlag@vt.edu
#SBATCH --mail-type=FAIL

###########################################################################
date
echo running on `hostname`
echo in job $SLURM_JOB_ID
echo with tmpfs $TMPFS
echo with tmpdir $TMPDIR

## starting the script, need day
start=$(date +%s)
today=$(date '+%D %T')
echo $today

module load singularity/3.5.1

#####################################
# need to make sure about 1 hours worth are in queue
#####################################
SECONDS=0
echo FILL THE QUEUES
cd $SLURM_SUBMIT_DIR

## fill the queue for 1 hour and handle ones that may have bombed out due to scheduler issues
for i in {00..50..10}; do
        in_queue=$(squeue -h -u rsettlag --states=pending --name=qstat.$i |  wc -l)
        if [ $in_queue -eq 0 ]; then
                nextrun=$(date -d "+1hour" +'%H:')$i":00"
                sbatch --begin=$nextrun \
			--job-name=qstat.$i \
			--export=NONE /groups/predictHPC/day_summaries/dragonstooth/SLURM_OOD_report_cron.sh
        fi
done
echo time to fill queue was $SECONDS
#####################################
# this gets snapshot of what node counts are in what state
#####################################
SECONDS=0
cd /home/rsettlag/quick_start/

echo START PULLING STATS
bash ~/quick_start/dt_current_status.sh 
ssh -q -J dtlogin1 cascades1.arc.vt.edu bash ~/quick_start/ca_current_status.sh
ssh -q -J dtlogin1 huckleberry1.arc.vt.edu bash ~/quick_start/hu_current_status.sh
ssh -q -J dtlogin1 tinkercliffs1.arc.vt.edu bash ~/quick_start/tc_current_status.sh
echo END PULLING STATS
echo time to pull stats was $SECONDS
#####################################
# this creates the summaries
#####################################
SECONDS=0
echo CREATE SUMMARIES
singularity exec --bind=/home/rsettlag/quick_start/profiles:/etc/rstudio/profiles,/home/rsettlag/quick_start/Rprofile.site:/usr/local/lib/R/etc/Rprofile.site \
   /groups/arcsingularity/ood-rstudio-bio_3.6.2.sif Rscript current_status2.R
echo 
echo now plot them
echo
singularity exec --bind=/home/rsettlag/quick_start/profiles:/etc/rstudio/profiles,/home/rsettlag/quick_start/Rprofile.site:/usr/local/lib/R/etc/Rprofile.site  \
   /groups/arcsingularity/ood-rstudio-bio_3.6.2.sif Rscript create_plot.R

#singularity exec --bind=/home/rsettlag/quick_start/profiles:/etc/rstudio/profiles,/home/rsettlag/quick_start/Rprofile.site:/usr/local/lib/R/etc/Rprofile.site  \
#   /groups/arcsingularity/ood-rstudio-bio_3.6.2.sif Rscript create_waittime_plot.R
echo DONE CREATING SUMMARIES
echo time to create summaries was $SECONDS
#####################################
# get current QoS
#####################################
SECONDS=0
echo get QoS
sacctmgr show qos format=Name,Flags,GrpTRESRunMins,MaxTRESMinsPerJob,MaxJobsPA,MaxJobsPU,MaxSubmitJobsPerAccount,MaxSubmitJobsPerUser,MaxTRESPA,MaxTRESPU,MaxTRESMins --parsable2 > QoS_settings.txt
echo DONE
echo time to get QoS was $SECONDS
#####################################
# this updates the splash screen for OOD
#####################################
SECONDS=0
echo UPDATE MOTD
cat ~/quick_start/preprod_message.md ~/quick_start/cluster_stats.txt > /home/arcadm/oodmotd/preprod.md
cat ~/quick_start/prod_message.md ~/quick_start/cluster_stats.txt > /home/arcadm/oodmotd/prod.md

cat /home/arcadm/oodmotd/prod.md
echo DONE 
echo time to update MOTD was $SECONDS
#####################################
# need to push to github
#####################################
SECONDS=0
echo PUSH TO GITHUB

# need to remove git index.lock file if it exists
# this would most likely be due to a prematurely finished job
if [ -f "/home/rsettlag/quick_start/.git/index.lock" ]; then
  rm /home/rsettlag/quick_start/.git/index.lock
fi

git add *.jpg
git add *.RDS
git add *.txt
git commit -m "update data and pics"
ssh -q -J dtlogin1 cascades1.arc.vt.edu bash ~/quick_start/ca_git_push.sh
echo DONE WITH GITHUB
echo time to push to GITHUB was $SECONDS
###########################################################################
end=$(date +%s)
echo script took echo $((end - start))
echo DONE DONE
exit;
