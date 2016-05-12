#!/bin/bash
cd ~/Documents/Code/Blog-Hexo-Source/source/_posts/
touch tempfile
IFS=$'\n'
find . -name '*.md' |
while read article
do
  cat $article | while IFS='' read LINE || [[ -n "$LINE" ]];
  do
    count=0
    for ((i=0;i<${#LINE};i++))
    do
      if [[ ${LINE:i:1} = "#" ]]; then
        # count number of title marker:'#'
        ((count++))
      else
        if [[ ${LINE:i:1} != " " && $i = $count ]]; then
          # There is no space after title marker
          istitle=false
          if [[ ${count} > 1 ]]; then
            # number of '#' more than one, pass!
            istitle=true
          elif [[ ${count} = 1 ]]; then
            if [[ ${LINE:i:2} != "if" \
            && ${LINE:i:4} != "else" \
            && ${LINE:i:5} != "endif" \
            && ${LINE:i:6} != "define" \
            && ${LINE:i:5} != "undef" \
            && ${LINE:i:6} != "import" \
            && ${LINE:i:6} != "pragma" ]]; then
              # number of '#' equals to one, but not macro codes. pass!
              istitle=true
            fi
          fi
          if [[ "$istitle" = true ]]; then
            # add space before title content
            LINE=${LINE:0:count}" "${LINE:count}
          fi
        fi
        count=0
      fi
    done
    echo $LINE >> ./tempfile
  done
cp ./tempfile $article
# cp ./tempfile ~/Desktop/md/"$article"
# clear tempfile
: > ./tempfile
done
rm ./tempfile
