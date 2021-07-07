#!/bin/bash

#██████████████████████████████████████████████████████████████ DATE TODAY ███
# must set the time to Namibian :)
TODAY=$(TZ="Africa/Windhoek" date '+%A %d-%B, %Y')

echo "${TODAY}" > .active

git add .
git commit -am"active on ${TODAY}"
git push

exit 0
