#!/bin/bash

# Domain wise mail traffic reports for qmail(syslog) using qmailanalog
# ...by  Jay Nambiar

#Modifications : 
#24 Mar 2003-- Log Path changed
#28 Feb 2003-- Functions added (Single file execution)   
#Changed reoprt format from weekly to monthly


#MAILLOG="$1"
#MAILLOG="`find /mnt/hdb6/backup/log -mtime -1 -type f -name "maillog.*"`"
MAILLOG="/mnt/hdb6/backup/log/maillog.`date -d '1 day ago' +%d-%m-%Y-23-59`"

if [ ! -f $MAILLOG ]
then
MAILLOG="`find /mnt/hdb6/backup/log -maxdepth 1 -mtime -1 -type f -name "maillog.*"`"
fi


NEWLOG="/var/log/maillog"

TMPLOG="/tmp/qmail.$$"
MATCHLOG="/tmp/match.$$"
SENT="/tmp/sent.$$"
RECD="/tmp/recd.$$"
tmpdir="/tmp/qmail-cron.$$.$RANDOM"

rdate="`date -d '1 day ago' +%b%e`"
l_date=`date -d '1 day ago' +'%b %e'`

tmpdatadir="/root/tmp"
sumdir="$tmpdatadir/summary"
reportdir="/www/websites/abc-india.com/qmail"
#reportdir="/var/www/html/qmail"
outputdir="$reportdir/`date -d '1 day ago' +%b%Y`"

domainlist="/root/qdomains"



function byte {
if [ $1 -ge 1000000000 ]
then
echo "<TD> `echo "scale=2;$1 / 1000000000" | bc` GB </TD>"
else
if [ $1 -ge 1000000 ]
then
echo "<TD> `echo "scale=2;$1 / 1000000" | bc` MB </TD>"
else
echo "<TD> `echo "scale=2;$1 / 1000" | bc` KB </TD>"
fi
fi
}



function new-html {

echo "<HTML>
<TITLE>$1</TITLE>
<H3>Mail Traffic Analysis for $1 </H3>

<TABLE BORDER>
<TR ALIGN=CENTER>
<TD> DATE </TD> <TD>  SENT(No)</TD> <TD>  SENT(Bytes)</TD><TD>RECEIVED(No)</TD><TD> RECEIVED(Bytes) </TD> <TD> TOTAL(No) </TD> <TD> TOTAL(Bytes) </TD> <TD> TOTAL(in GB/MB/KB) </TD>
</TR>

<TR>"
}




function data-html {

declare -a sent_data
declare -a recd_data
declare -a totalsize
totalsize=0
count1=0
count2=0

pushd $2 > /dev/null

echo "<TR ALIGN=RIGHT>
<TD>  "$4" </TD>"

if [ -s $1.senttotal ]
then

for k in `cat $1.senttotal`

do
sent_data[$count1]=$k
count1=`expr $count1 + 1`
echo "<TD> $k </TD>"
done

else

sent_data[0]=0
sent_data[1]=0
echo "<TD> 0 </TD><TD> 0 </TD>"

fi


if [ -s $1.recdtotal ]
then

for k in `cat $1.recdtotal`

do
recd_data[$count2]=$k
count2=`expr $count2 + 1`
echo "<TD> $k </TD>"
done

else
echo "<TD> 0 </TD><TD> 0 </TD>"
recd_data[0]=0
recd_data[1]=0

fi


totalsize[0]=`expr ${sent_data[1]} + ${recd_data[1]}`

echo "<TD> `expr ${sent_data[0]} + ${recd_data[0]}` </TD>" "<TD> `expr ${sent_data[1]} + ${recd_data[1]}` </TD>"

echo `expr ${sent_data[0]} + ${recd_data[0]}` " " `expr ${sent_data[1]} + ${recd_data[1]}` >> $3/$1.total


byte ${totalsize[0]}


echo "</TR>"

popd > /dev/null

}



function footer-html {

mailtotal=`awk '{OFMT="%i";total+=$1;print total}' $2/$1.total | tail -1`
bytetotal=`awk '{OFMT="%i";total+=$2;print total}' $2/$1.total | tail -1`


echo "</TABLE>
<H4> Total Mails = "$mailtotal"</H4>
<H4> Total Bytes = $(byte $bytetotal)  </H4>
</HTML>"

}



if [ ! -d $tmpdatadir ]
then
mkdir $tmpdatadir
fi

touch $tmpdatadir/log.old

if [ ! -d $sumdir ]
then
mkdir $sumdir
fi



if [ ! -d $reportdir ]
then
mkdir $reportdir
fi

if [ ! -d $outputdir ]
then
mkdir $outputdir
rm -f $sumdir/*.total
fi


l_date=`date -d '1 day ago' +'%b %e'`

day="$l_date"

grep -h "$day" $MAILLOG $NEWLOG | grep qmail: |  awk '{$1="";$2="";$3="";$4="";$5="";print}' > $TMPLOG

cat $TMPLOG $tmpdatadir/log.old | /usr/local/qmailanalog/bin/matchup > $MATCHLOG 5>$tmpdatadir/log

mv $tmpdatadir/log $tmpdatadir/log.old


cat $MATCHLOG | /usr/local/qmailanalog/bin/senders > $SENT

cat $MATCHLOG | /usr/local/qmailanalog/bin/recipients > $RECD





mkdir $tmpdir

for i in `cat $domainlist`
do
grep @$i $SENT > $tmpdir/$i.sent
cat $tmpdir/$i.sent | awk '{sum+=$1;total+=$2;print sum "\t" total}' | tail -1 > $tmpdir/$i.senttotal
done


for i in `cat $domainlist`
do
grep @$i $RECD > $tmpdir/$i.recd
cat $tmpdir/$i.recd | awk '{total+=$1;sum+=$2;print sum "\t" total}' | tail -1 > $tmpdir/$i.recdtotal
done



if [ `date +%e` = 2 ] 
then 

rm -f $sumdir/*.total
for i in `cat $domainlist`
do 
new-html $i > $outputdir/$i.html
done
 
fi 



for i in `cat $domainlist`
do
if [ ! -e $outputdir/$i.html ]
then
new-html $i > $outputdir/$i.html
fi
data-html $i $tmpdir $sumdir "$rdate" >> $outputdir/$i.html
done


if [ `date +%e` = 1 ]
then

for i in `cat $domainlist`
do
footer-html $i $sumdir >> $outputdir/$i.html
done

#newdir="$reportdir/`date -d '1 day ago' +'%b%d'`"
#mkdir $newdir
#mv $outputdir/*.html $newdir/
fi

rm -f $TMPLOG
rm -f $MATCHLOG
rm -f $SENT
rm -f $RECD
rm -rf $tmpdir


