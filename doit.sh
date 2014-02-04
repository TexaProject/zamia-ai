#!/bin/bash

rm -rf output
mkdir output
mkdir output/logs
mkdir output/dict
mkdir output/lm
mkdir output/grammar

#
# audio model
#

./audio-gen-model.py >output/logs/genmodel.log

./lm-export-dict.py 

cp -r /home/ai/voxforge/de/work/acoustic_model_files output/
cp /home/ai/voxforge/de/work/dict.txt output/dict
cp /home/ai/voxforge/de/lm/dict-julius.txt output/dict
cp /home/ai/voxforge/de/work/logs/Step* output/logs

# 
# language model
#

./lm-prompts.py
pushd /home/ai/voxforge/de/lm

rm -f *.rev
rm -f *.arpa
rm -f *.params
rm -f *.bingram
rm -f all.sent all.rev

~/projects/ai/speech/lm-reverse.pl prompts.sent > prompts.rev
~/projects/ai/speech/lm-reverse.pl parole.sent >parole.rev
# ~/projects/ai/speech/lm-reverse.pl europarl.sent >europarl.rev

# merge
cat prompts.sent parole.sent > all.sent
cat prompts.rev parole.rev > all.rev

# When using limited vocabularies it is recommended to compute the
# discount coeffiecients on the unlimited vocabulary (at least for
# the unigrams) and then apply them to the limited vocabulary
# (otherwise the vocabulary truncation would produce badly skewed
# counts frequencies at the low end that would break the GT algorithm.)

rm -f gt*.params
ngram-count -order 2 -text all.sent -unk -gt1 gt1.params -gt2 gt2.params 
ngram-count -order 2 -text all.sent -unk  -gt1 gt1.params -gt2 gt2.params -lm german.arpa -vocab wlist.txt

rm -f gt*.params
ngram-count -order 4 -text all.rev -unk -gt1 gt1.params -gt2 gt2.params -gt3 gt3.params -gt4 gt4.params 
ngram-count -order 4 -text all.rev -unk -gt1 gt1.params -gt2 gt2.params -gt3 gt3.params -gt4 gt4.params -lm german-rev.arpa -vocab wlist.txt

#ngram-count -order 2 -text prompts.sent -text parole.sent -unk -gt1min 1 -gt2min 2 -kndiscount1 -kndiscount2 -interpolate1 -interpolate2 -lm german.arpa -vocab wlist.txt
#ngram-count -order 4 -text prompts.rev -text parole.rev -unk -gt1min 1 -gt2min 2 -gt3min 2 -gt4min 2 -kndiscount1 -kndiscount2 -kndiscount3 -kndiscount4 -interpolate1 -interpolate2 -interpolate3 -interpolate4 -lm german-rev.arpa -vocab wlist.txt

# ngram-count -order 2 -text prompts.sent -unk -kndiscount1 -kndiscount2 -kndiscount3 -lm german.arpa -vocab wlist.txt
# ngram-count -order 4 -text prompts.rev -unk -kndiscount1 -kndiscount2 -kndiscount3 -lm german-rev.arpa -vocab wlist.txt
#
# ngram-count -order 2 -text prompts.sent -text europarl.sent -text parole.sent -unk -kndiscount1 -kndiscount2 -kndiscount3 -lm german.arpa -vocab wlist.txt
# ngram-count -order 4 -text prompts.rev -text europarl.rev -text parole.rev -unk -kndiscount1 -kndiscount2 -kndiscount3 -lm german-rev.arpa -vocab wlist.txt
#
# ngram-count -order 2 -text prompts.sent -unk -lm german.arpa -vocab wlist.txt
# ngram-count -order 4 -text prompts.rev -unk -lm german-rev.arpa -vocab wlist.txt

mkbingram -nlr german.arpa -nrl german-rev.arpa german.bingram
popd

cp /home/ai/voxforge/de/lm/german.bingram output/lm
cp /home/ai/voxforge/de/lm/wlist.txt output/lm
#cp /home/ai/voxforge/de/lm/*.sent output/lm
#cp /home/ai/voxforge/de/lm/*.rev output/lm

#
# eval
#

./eval-model.py >output/logs/eval-lm.log

#
# grammar / dfa
#

./grammar-gen.py
pushd output/grammar
mkdfa.pl eval >../logs/mkdfa.log
popd

#
# eval grammar
#

./eval-grammar.py >output/logs/eval-grammar.log

#
# export data, db dump
#

./audio-stats.py >output/audio-stats.txt

DSTR=`date +%y%m%d%H%M`
./audio-stats.py >priv/stats/audio-stats-$DSTR.txt

pg_dump -U lexicon lexicon_de >output/db.sql
gzip output/db.sql

cp README.md output/readme.txt

./audio-export-csv.py >output/audio-transcripts.csv
./lex-export.py

#
# upload
#

#rsync -avPz --delete output/ goofy:/var/www/html/voxforge/de
