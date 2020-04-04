#!/bin/sh 

#获取BUCKET
for BUCKET in $(ls $1/) 
do
	BTRUE=0
	touch $1/../delblock 	
	echo " " >$1/../dellog
	#获取bucket下所有块
	echo $BUCKET 
	s3cmd ls s3://$BUCKET/ | awk '{print $2}' | grep -v 'debug'  > $1/$BUCKET/block
	sed -i "s/s3:\/\/$BUCKET\///g" $1/$BUCKET/block
	sed -i "s/\///g" $1/$BUCKET/block

	#删除不完整的块
	echo "开始删除不完整块"
	for BLOCKNAME in $(cat $1/$BUCKET/block ) 
	do 
		echo $BLOCKNAME

		CHUNKCOUNT=`s3cmd ls s3://$BUCKET/$BLOCKNAME/chunks/  | wc -l`
		LASTCHUNK=`s3cmd ls s3://$BUCKET/$BLOCKNAME/chunks/  | awk '{print $4}'  | tail -n 1`
		LASTCHUNK=`echo ${LASTCHUNK:0-6:6}`
		
		RESULT=`echo $LASTCHUNK |grep $CHUNKCOUNT`
		if [[ "$RESULT" != "" ]]
		then
			echo "s3://$BUCKET/$BLOCKNAME is complete"
		else
			echo "$2 $BLOCKNAME not completed, delete this block"
			echo "s3cmd del --recursive s3://$BUCKET/$BLOCKNAME"
			echo "s3cmd del --recursive s3://$BUCKET/$BLOCKNAME" >>$1/../dellog
			s3cmd del --recursive s3://$BUCKET/$BLOCKNAME
			sed   -i "/$BLOCKNAME/d"  $1/$BUCKET/block
		fi	
		
		echo $BLOCKNAME done
	done
	echo "删除不完整块完成"

	#获取block 详细信息
	for BLOCKNAME in $(cat  $1/$BUCKET/block )
	do
		echo $BLOCKNAME
		s3cmd  get  s3://$BUCKET/$BLOCKNAME/meta.json  $1/meta.json
		
		#只筛选为开始 downsample 的块，也就是compact 块
		STARTDOWNSAMPLE=`cat  $1/meta.json  |grep resolution | awk '{print $2}'`
		if [ "$STARTDOWNSAMPLE" = "0" ]
		then
			#是哪台prometheus 的block 以它建立目录
			PROMETHEUS=`cat  $1/meta.json  | grep "prometheus" | awk '{print $2}' | sed "s/\"//g"`
			echo "mkdir -p  $1/$BUCKET/$PROMETHEUS/$BLOCKNAME"
			mkdir -p  $1/$BUCKET/$PROMETHEUS/$BLOCKNAME
			
			#获取块的详细信息
			cat $1/meta.json | grep minTime | head -n 1 | awk '{print $2}' | awk '{sub(/.$/,"")}1' > $1/$BUCKET/$PROMETHEUS/$BLOCKNAME/min
			cat $1/meta.json | grep maxTime | head -n 1 | awk '{print $2}' | awk '{sub(/.$/,"")}1' > $1/$BUCKET/$PROMETHEUS/$BLOCKNAME/max
		fi
			
		\rm -rf $1/meta.json
	done

	echo "开始删除重复模块"
	for PROMETHEUS in $(ls  $1/$BUCKET | grep -v "block") 
        do
		
		#遍历同一台prometheus下的所有块
		for OBLOCK in $(ls  $1/$BUCKET/$PROMETHEUS/ |grep -v "block")
		do
                        for DELBLOCK in $(cat $1/../delblock )	
			do
				if [ "$DELBLOCK" == "$OBLOCK" ]
				then
					BTRUE=1
					break
				fi
			done 

			if [ "$BTRUE" = 1 ]
			then 
				BTRUE=0
				continue
			fi

			echo "$OBLOCK"
			MIN=`cat $1/$BUCKET/$PROMETHEUS/$OBLOCK/min`
			MAX=`cat $1/$BUCKET/$PROMETHEUS/$OBLOCK/max`
			
			#和所有块进行比较
			for BLOCKNAME in $(ls  $1/$BUCKET/$PROMETHEUS/ | grep -v $OBLOCK |grep -v "block")
			do
				MINCURRENT=`cat $1/$BUCKET/$PROMETHEUS/$BLOCKNAME/min`
				MAXCURRENT=`cat $1/$BUCKET/$PROMETHEUS/$BLOCKNAME/max`
				if [ "$MIN" -le "$MINCURRENT" -a "$MAX" -ge "$MAXCURRENT" ]
				then
					echo "$MIN $MINCURRENT $MAXCURRENT $MAX"
					echo "DUPLCIATE BLOCK $OBLOCK AND $BLOCKNAME"
					s3cmd del --recursive s3://$BUCKET/$BLOCKNAME
					echo "s3cmd del --recursive s3://$BUCKET/$BLOCKNAME" >>$1/../dellog
					echo "$BLOCKNAME" >> $1/../delblock
					\rm -rf  $1/$BUCKET/$PROMETHEUS/$BLOCKNAME/		
				fi
			done
			echo "$OBLOCK done"	
		done
		\rm -rf $1/$BUCKET/$PROMETHEUS
	done
	echo "删除重复块完成"
done

