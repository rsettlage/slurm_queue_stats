#!/bin/bash

module load singularity/3.5.1
singularity exec --bind=/home/rsettlag/quick_start/profiles:/etc/rstudio/profiles,/home/rsettlag/quick_start/Rprofile.site:/usr/local/lib/R/etc/Rprofile.site \
   /groups/arcsingularity/ood-rstudio-bio_3.6.2.sif Rscript current_status.R

cat preprod_message.md cluster_stats.txt >/home/arcadm/oodmotd/preprod.md

echo finished getting, munging, creating and summarizing status, updated MOTD
exit;
