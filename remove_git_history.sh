## The argument to the script ($1) is a reference (tag, hash, ...) to the commit starting from which you want to keep 

#!/bin/bash
git checkout --orphan temp $1 # create a new branch without parent history
git commit -m "Truncated history" # create a first commit on this branch
git rebase --onto temp $1 master # now rebase the part of master branch that we want to keep onto this branch
git branch -D temp # delete the temp branch

# The following 2 commands are optional - they keep your git repo in good shape.
git prune --progress # delete all the objects w/o references
git gc --aggressive # aggressively collect garbage; may take a lot of time on large repos

## need to manually git pull, git push to finish
