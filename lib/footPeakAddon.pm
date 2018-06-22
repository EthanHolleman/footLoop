package footPeakAddon;

use strict; use warnings; use Getopt::Std; use FAlite; use Cwd qw(abs_path); use File::Basename qw(dirname);
use vars qw($opt_v $opt_x $opt_R $opt_c $opt_t);

##### BEGIN ######
BEGIN {
   my $libPath = dirname(dirname abs_path $0) . '/footLoop/lib';
   push(@INC, $libPath);
}
use myFootLib; use FAlite;
my $homedir = $ENV{"HOME"};
my $footLoopScriptsFolder = dirname(dirname abs_path $0) . "/footLoop";
my ($thisfileName) = getFilename($0, "fullname");
my ($thismd5) = getMD5_simple($0);
sub main {
	# From footPeak.pl: 
	# $peakFilez, $seqFile, $gene, $minDis, $resDir, $minLen, $SEQ;
	my ($input1, $faFile, $mygene, $minDis, $resDir, $minLen, $SEQ, $version, $outLog) = @_;
	LOG($outLog, "
$YW-------------------------------$N
 footPeakAddon.pm version $version
$YW-------------------------------$N
");

	#DIELOG($outLog, $0, "Usage: $YW$0$N [-c to use cpg] $CY<CALM3_Pos_20_0.65_CG.PEAK>$N $CY<location with lots of C>$N\n\n") unless @_ == 7;
	#DIELOG($outLog, date() . "footPeakAddon.pm: Input cannot be directry!\n") and exit 1 if -d $input1;
	my @foldershort = split("\/", $resDir);
	my $foldershort = pop(@foldershort);
	($input1) = getFullpath($input1);
	my ($folder, $fileName) = getFilename($input1, "folderfull");

	makedir("$resDir/.CALL") if not -d "$resDir/\.CALL";
	makedir("$resDir/PEAKS_GENOME") if not -d "$resDir/PEAKS_GENOME";
	makedir("$resDir/PEAKS_LOCAL") if not -d "$resDir/PEAKS_LOCAL";

	my @coor = split("\t", $SEQ->{$mygene}{coor});
	my (%pk, %Rscripts, %files);
	my $total = make_total_hash();

	my $label = "";
	if (-e "$resDir/.LABEL") {
	   ($label) = `cat $resDir/.LABEL`;
	   chomp($label);
	}
	else {
		DIELOG($outLog, "Failed to parse label from .LABEL in $resDir/.LABEL\n");
	}
	my ($label2, $gene, $strand, $window, $thres, $type) = parseName($fileName);# =~ /^(.+)_gene(.+)_(Unk|Pos|Neg)_(\d+)_(\d+\.?\d*)_(\w+)\.(PEAK|NOPK)$/;
	my $isPeak = $fileName =~ /\.PEAK/ ? "PEAK" : "NOPK";
	LOG($outLog, "Using label=$label2. Inconsistent label in filename $LCY$fileName$N\nLabel from $resDir/.LABEL: $label\nBut from fileName: $label2\n\n") if $label ne $label2;
	$label = $label2;

	if (defined $mygene) {
		LOG($outLog, date() . "footPeak.pl filename=$LCY$fileName$N, mygene=$mygene, input genez=$gene are not the same!\n") and return -1 if uc($mygene) ne uc($gene);;
	} else {$mygene = $gene;}
	
	my $bad = find_lots_of_C($faFile, $mygene, $outLog) if defined $faFile;

	LOG($outLog, date() . "$input1; Undefined mygene=$mygene=, strand=$strand=, window=$window=, thres=$thres=, type=$type=, isPeak=$isPeak=\n") and exit 1 if not defined $isPeak or not defined $window;
	LOG($outLog, date . "\n\nFolder $YW$folder$N: Processing files related to $LCY$input1$N\n");
	my @types = qw(CH CG GH GC);
	for (my $h = 0; $h < 4; $h++) {
		my $type = $types[$h];
		my $peakFile   = "$resDir/.CALL/$label\_gene$mygene\_$strand\_$window\_$thres\_$type.PEAK";
		my $nopkFile   = "$resDir/.CALL/$label\_gene$mygene\_$strand\_$window\_$thres\_$type.NOPK";
		$files{$peakFile} = 1;
		LOG($outLog, date . "h=$LGN$h\t$YW$peakFile\t$LCY$nopkFile\n$N");
	
		my ($folder1, $peakfileName) = getFilename($peakFile, "folderfull");
		my ($folder2, $nopkfileName) = getFilename($nopkFile, "folderfull");

		my $data;
		my ($linecount, $totalpeak, $totalnopk, $totalline) = (0,0,0,0);
		if (-e $nopkFile) {
			($totalline) = `wc -l $nopkFile` =~ /^(\d+)/;
			$linecount = 0;
			open (my $in1, "<", $nopkFile) or LOG($outLog, date() . "Cannot read from $nopkFile: $!\n") and exit 1;
			LOG($outLog, date . "\tProcessing NOPK file $LPR$nopkFile$N ($LGN$totalline$N lines)\n");
			while (my $line = <$in1>) {
				chomp($line);
				$linecount ++;
				next if $linecount == 1; #header
				LOG($outLog, date . "\tDone $totalnopk / $totalline\n") if $totalnopk % 500 == 0;
				my ($name, $val, $totalPeak, $peaks) = parse_peak($line, $bad, $minDis, $minLen, $outLog);
				$val = "$name\t" . join("\t", @{$val});
				push(@{$data->{peak}}, $val) if $totalPeak > 0;
				push(@{$data->{nopk}}, $val) if $totalPeak == 0;
				$totalnopk ++;
				$pk{$peakFile}{$name} = $peaks if defined $peaks;
			}
			close $in1;
		}
		my $peakCount = defined $data->{peak} ? @{$data->{peak}} : 0;
		my $nopkCount = defined $data->{nopk} ? @{$data->{nopk}} : 0;
		my $nopkPrint ="$folder2\t$nopkfileName\t$peakCount\t$nopkCount\t$totalnopk\t$totalline";
		LOG($outLog, date() . "$nopkPrint\n");
		$total->{$type}{peak}  += $peakCount;
		$total->{$type}{nopk}  += $nopkCount;
		$total->{$type}{total} += $totalnopk;
		
		if (-e $peakFile) {
			($totalline) = `wc -l $peakFile` =~ /^(\d+)/;
			$linecount = 0;
			open (my $in1, "<", $peakFile) or LOG($outLog, date() . "Cannot read from $peakFile: $!\n") and exit 1;
			LOG($outLog, date . "\tProcessing PEAK file $LPR$peakFile$N ($LGN$totalline$N lines)\n");
			while (my $line = <$in1>) {
				chomp($line);
				$linecount ++;
				next if $linecount == 1; #header
				LOG($outLog, date . "\tDone $totalpeak / $totalline\n") if $totalpeak % 500 == 0;
				my ($name, $val, $totalPeak, $peaks) = parse_peak($line, $bad, $minDis, $minLen, $outLog);
				$val = "$name\t" . join("\t", @{$val});
				push(@{$data->{peak}}, $val) if $totalPeak > 0;
				push(@{$data->{nopk}}, $val) if $totalPeak == 0;
				$totalpeak ++;
				$pk{$peakFile}{$name} = $peaks if defined $peaks;
			}
			close $in1;
		}
		$peakCount = defined $data->{peak} ? @{$data->{peak}} - $peakCount : 0;
		$nopkCount = defined $data->{nopk} ? @{$data->{nopk}} - $nopkCount : 0;
		my $peakPrint ="$folder1\t$peakfileName\t$peakCount\t$nopkCount\t$totalpeak\t$totalline";
		LOG($outLog, date() . "$peakPrint\n");
		$total->{$type}{peak}  += $peakCount;
		$total->{$type}{nopk}  += $nopkCount;
		$total->{$type}{total} += $totalpeak;

		if (defined $data->{peak}) {
			die if @{$data->{peak}} != $total->{$type}{peak};
			#print "HERE: $folder1/$peakfileName.out\n";
			open (my $out1, ">", "$resDir/.CALL/$peakfileName.out") or LOG($outLog, date() . "Cannot write to $peakfileName.out: $!\n") and exit 1;
			foreach my $val (sort @{$data->{peak}}) {
				print $out1 "$val\n";
			}
			close $out1;
		}
		if (defined $data->{nopk}) {
			die if @{$data->{nopk}} != $total->{$type}{nopk};
			#print "HERE: $folder1/$nopkfileName.out\n";
			open (my $out1, ">", "$resDir/.CALL/$nopkfileName.out") or LOG($outLog, date() . "Cannot write to $nopkfileName.out: $!\n") and exit 1;
			foreach my $val (sort @{$data->{nopk}}) {
				print $out1 "$val\n";
			}
			close $out1;
		}		
		LOG($outLog, date . "#Folder\tFile\tPeak\tnopk\tTotalRead\tTotalLineInFile\n") if $h == 0;
		LOG($outLog, date . "$peakPrint\n$nopkPrint\n");
	}
	my ($chr0, $beg0, $end0, $name0, $val0, $strand0) = @coor;
	my $STRAND = $strand0;
	die "Undefined beg or end at coor=\n" . join("\n", @coor) . "\n" if not defined $beg0 or not defined $end0;
	
#	system("footPeak_HMM.pl -n $resDir");

	foreach my $file (sort keys %pk) {
		my ($pk_filename) = getFilename($file, 'full');
		open (my $outPEAKS, ">", "$resDir/PEAKS_GENOME/$pk_filename.genome.bed")   or LOG($outLog, "\tFailed to write into $resDir/PEAKS_GENOME/$pk_filename.genome.bed: $!\n")  and exit 1;
		open (my $outRPEAKS, ">", "$resDir/PEAKS_LOCAL/$pk_filename.local.bed") or LOG($outLog, "\tFailed to write into $resDir/PEAKS_LOCAL/$pk_filename.local.bed: $!\n") and exit 1;
		my $currtype = $file =~ /_CH/ ? "CH" : $file =~ /_CG/ ? "CG" : $file =~ /_GH/ ? "GH" : $file =~ /_GC/ ? "GC" : "UNK";
		LOG($outLog, "\tFailed to determine type (CH/CG/GH/GC) of file=$file.PEAKS: $!\n") if $currtype eq "UNK";
		foreach my $name (sort keys %{$pk{$file}}) {
			foreach my $peak (sort @{$pk{$file}{$name}}) {
				my ($beg, $end) = split("-", $peak);
				my $end1 = $end + $beg0;
				my $beg1 = $beg + $beg0;
				my ($junk, $readname) = $name =~ /^(\w+)\.(.+)$/;
				print $outPEAKS  "$chr0\t$beg1\t$end1\t$name\t0\t$strand0\t$file\n";
				print $outRPEAKS "$name\t$beg\t$end\n";
			}
		}
		close $outPEAKS;
		close $outRPEAKS;
	}
	
	makedir("$resDir/99_FOOTSTATS/") if not -d "$resDir/99_FOOTSTATS/";
	makedir("$resDir/99_FOOTSTATS/.PEAKSTATSTEMP") if not -d "$resDir/99_FOOTSTATS/.PEAKSTATSTEMP";
	open (my $outLGENE, ">", "$resDir/99_FOOTSTATS/.PEAKSTATSTEMP/.0_RESULTS\_$label\_gene$mygene\_$strand\_$window\_$thres.TXT");
	print $outLGENE "#folder\tpeak_file\tgene\tread_strand\tread_unique_total\tread_unique_with_peak_total\tread_unique_with_peak_perc\n";
	for (my $h = 0; $h < 4; $h++) {
		my $type = $types[$h];
		my $totalPeak = $total->{$type}{peak};
		my $totalNopk = $total->{$type}{nopk};
		$total->{$type}{peak} = $total->{$type}{total} == 0 ? 0 : int(1000 * $total->{$type}{peak} / $total->{$type}{total}+0.5)/10;
		$total->{$type}{nopk} = $total->{$type}{total} == 0 ? 0 : int(1000 * $total->{$type}{nopk} / $total->{$type}{total}+0.5)/10;
		my @folder = split("/", $resDir);
		my $foldershort = $folder[@folder-1];
		   $foldershort = $folder[@folder-2] if not defined ($foldershort) or (defined $foldershort and $foldershort =~ /^[\s]*$/);
		my $peakFile    = "$label\_gene$mygene\_$strand\_$window\_$thres\_$type.PEAK";
		print $outLGENE "$foldershort\t$peakFile\t$mygene\t$type\t$total->{$type}{total}\t$totalPeak\t$total->{$type}{peak}\n";
	}
	close $outLGENE;
	system("cat $resDir/99_FOOTSTATS/.PEAKSTATSTEMP/.0_RESULTS\_$label\_gene$mygene\_$strand\_$window\_$thres.TXT");
	#my ($sampleName) = $folder =~ /\/?\d+_(m\d+_\d+)_\d+_\w+/;
	my ($sampleName) = $folder =~ /^.+(PCB[\_\-]*\d+)/i;
	if ($folder =~ /debarcode/) {
		my ($temp) = $folder =~ /_ccs_(\w+)/;
		$sampleName = $sampleName . "_$temp";
	}
	if (not defined $sampleName) {
		$sampleName = $foldershort;
	}
	#system("footClust.pl -n $resDir -G $gene") == 0 or LOG($outLog, "Failed to run footClust.pl : $!\n");
	#system("footPeak_kmer.pl -n $resDir -G $gene") == 0 or LOG($outLog, "Failed to run footClust2.pl : $!\n");
}

###############
# Subroutines #
###############


sub make_total_hash {
	my $total;
	my @types = qw(CH CG GH GC);
	foreach my $type (@types) {
		$total->{$type}{peak} = 0; 
		$total->{$type}{nopk} = 0;
		$total->{$type}{total} = 0;
	}
	return($total);
}

sub parse_peak {
	my ($ARG, $bad, $minDis, $minLen, $outLog) = @_;
	my ($name, $isPeak, $mygene, $type, $strand, @val) = split("\t", $ARG);
	my %bad = %{$bad} if defined $bad;
	my $name_want = "AIRN_PFC66_FORWARD.16024";#CALM3.m160130_030742_42145_c100934342550000001823210305251633_s1_p0/16024/ccs";
	shift(@val) if $val[0] eq "";
#	for (my $i = 0; $i < @val; $i++) {
#		if ($val[$i] !~ /^[456789]$/) {print "."} else {print "$val[$i]";}
#		LOG($outLog, date() . "\n") if $i != 0 and ($i+1) % 100 == 0;
#	}
#	LOG($outLog, date() . "\n");
#	0001234000
#	0123456789
#	len=10, e1=len(e1), e2=10-len(e2)
	my $peaks;
	my %peak; $peak{curr} = 0; #my $edge = 0; my $edge2 = 0; my $zero = 0; my $edge1 = 0;
	my $Length = @val; 
	my $print = "name=$name, isPeak = $isPeak, Total length = $Length\n";
	my ($edge1) = join("", @val) =~ /^(0+)[\.1-9A-Za-z]/;
	$edge1 = defined $edge1 ? length($edge1) : 0;
	my ($edge2) = join("", @val) =~ /[\.1-9A-Za-z](0+)$/;
	$edge2 = defined $edge2 ? @val-length($edge2) : @val;
	for (my $i = 0; $i < @val; $i++) {
		my $val = $val[$i];
		if ($i % 100 == 0) {$print .= "\n$YW" . $i . "$N:\t";}
		if ($val[$i] =~ /[89]/) {
			$peak{beg} = $i if $peak{curr} == 0;
			$print .= "${LPR}$val[$i]$N" if $peak{curr} == 0;
			$print .= "${LRD}$val[$i]$N" if $peak{curr} == 1;
			$peak{curr} = 1;
		}
		elsif ($val[$i] =~ /[23]/) {
			$peak{end} = $i+1;
			push(@{$peak{peak}}, "$peak{beg}-$peak{end}");
			undef $peak{beg}; undef $peak{end};
			$peak{curr} = 0;
			$val[$i] =~ tr/23/89/;
			$print .= "${LPR}$val$N";
		}
		else {
			$print .= "EDGE1" if $i == $edge1;
			$print .= "${LGN}$val[$i]$N" if $val =~ /^[46]$/;
			$print .= "${LGN}$val[$i]$N" if $val =~ /^[57]$/;
			$print .= "." if $val[$i] eq 1;
			$print .= "x" if $val[$i] eq 0;# and $i < $edge1;
			$print .= "EDGE2" if $i == $edge2 - 1;
		}
	}
	my (%nopk, @peak);
	$strand = $type =~ /^C/ ? 0 : $type =~ /^G/ ? 16 : 255;
	my %peak2;
	$print .= "\n";
	print "$print" if $name_want eq $name;
#	LOG($outLog, date() . "\nDoing $YW$name$N\n" if $name eq $name_want;#"SEQ_76074" or $name eq "SEQ_34096" or $name eq "SEQ_62746");
	if (defined $peak{peak}) {
		foreach my $peak (sort @{$peak{peak}}) {
			my ($beg, $end) = split("-", $peak);
#			LOG($outLog, date() . "$name: $beg to $end\n" if $name eq 77011 or $name eq "$name_want");
			my $checkBad = 0;
#			if (not defined $bad->{$strand}) {
#				push(@peak, "$beg-$end");
#				push(@{$peak2{peak}}, $peak);
#			}
#			next if not defined $bad->{$strand};
			foreach my $begBad (sort keys %{$bad->{$strand}}) {
				my $endBad = $bad->{$strand}{$begBad};
#			foreach my $begBad (sort keys %bad) {
#				my $endBad = $bad->{$strand}{$begBad};
#				LOG($outLog, date() . "\t$beg-$end in begBad=$begBad to endBad=$endBad?\n" if $name eq "$name_want");
				if ($beg >= $begBad and $beg <= $endBad and $end >= $begBad and $end <= $endBad) {
#					for (my $m = $beg; $m <= $end; $m++) {
#						$nopk{$m} = 1;
#					}
					LOG($outLog, date() . "\t\t$LGN YES$N peak=$beg-$end, bad=$begBad-$endBad\n") if $isPeak eq "PEAK";# if $name eq "$name_want");
					$checkBad = 1; last;
				}
			}
			if ($checkBad != 1) {
				next if not defined $bad->{$strand};
				foreach my $begBad (sort keys %{$bad->{$strand}}) {
					my $endBad = $bad->{$strand}{$begBad};
#					LOG($outLog, date() . "$name: $beg-$end in begBad=$begBad to endBad=$endBad?\n" if $name eq "SEQ_76074" or $name eq "SEQ_34096" or $name eq "$name_want");
					#if (($beg >= $begBad and $beg <= $endBad) or ($end >= $begBad and $end <= $endBad)) {
						my @valz = @val;
						my ($goodC, $badC) = (0,0);
						for (my $m = $beg; $m < $end; $m++) {
							if ($m >= $begBad and $m <= $endBad) {
								$badC ++ if $valz[$m] =~ /[2389]/;
							}
							else {
								$goodC ++ if $valz[$m] =~ /[2389]/;
							}
						}
						if ($goodC < 5 and $badC >= 9) {
#							LOG($outLog, date() . "\t$LRD NO!$N beg=$beg, end=$end, begBad=$begBad, endBad=$endBad, badC = $badC, goodC = $goodC\n" if $name eq "SEQ_76074" or $name eq "SEQ_34096" or $name eq "SEQ_62746");
#							LOG($outLog, date() . "\t$YW$name$N $LRD NO!$N beg=$beg, end=$end, begBad=$begBad, endBad=$endBad, badC = $badC, goodC = $goodC\n");
							$checkBad = 1; last;
						}
				}
			}
#			LOG($outLog, date() . "\t$name checkbad = $checkBad\n" if $name eq "SEQ_76074" or $name eq "SEQ_34096" or $name eq "SEQ_62746");
			
			if ($checkBad == 1) {
				$print .= "\tCheckBad; Peak Not: $LRD$peak$N\n";
#				LOG($outLog, date() . "\tend=$end > 100 + edge1=$edge1 OR beg=$beg < edge2=$edge2-100; Peak bad : $LRD$peak$N\n" if $name eq "$name_want");
				for (my $j = $beg; $j <= $end; $j++) {
					$nopk{$j} = 1;
				}
			}
			elsif ($end - $beg < $minLen) {
				$print .= "\tend-$end < $minLen; Peak Not: $LRD$peak$N\n";
				for (my $j = $beg; $j <= $end; $j++) {
					$nopk{$j} = 1;
				}
			}
			elsif ($beg < $edge2 - 100 and $end > 100 + $edge1) {
#				LOG($outLog, date() . "something wrong\n";# if $name eq "$name_want");
				$print .= "\tend=$end > 100 + edge1=$edge1 OR beg=$beg < edge2=$edge2-100; Peak Used: $LGN$peak$N\n";
				push(@peak, "$beg-$end");
				push(@{$peak2{peak}}, $peak);
			}
			else {
				$print .= "\tbeg=$beg, end=4end, peak Not: $LRD$peak$N\n";
				for (my $j = $beg; $j <= $end; $j++) {
					$nopk{$j} = 1;
				}
			}
		}
	}
	my $totalpeak = scalar(@peak);
	my @val2 = @val;
	if ($totalpeak > 0) {
		for (my $i = 0; $i < @val; $i++) {
			my $val = $val[$i];
			$val2[$i] = $val;
			if ($val =~ /^(8|9)$/ and defined $nopk{$i}) { # Peak Converted CpG or CH
				$val2[$i] = 7 if $val eq 9;
				$val2[$i] = 6 if $val eq 8;
			}
		}
	}
	#die $print if $totalpeak > 1;
	$print .= "$name\t$totalpeak\n" if $isPeak eq "PEAK";
#	LOG($outLog, date() . "$print\n" if $isPeak eq "PEAK";# and $print =~ /; Peak Not/;# if $totalpeak == 1;# or $name eq "SEQ_100022") and exit 1;
#	exit 0 if $isPeak eq "PEAK";
	@val = @val2;
	$print .= "\n\nVAL2: Total length = $Length\n";
	($edge1) = join("", @val) =~ /^(0+)[\.1-9A-Za-z]/;
	$edge1 = defined $edge1 ? length($edge1) : 0;
	($edge2) = join("", @val) =~ /[\.1-9A-Za-z](0+)$/;
	$edge2 = defined $edge2 ? @val-length($edge2) : @val;
	for (my $i = 0; $i < @val; $i++) {
		my $val = $val[$i];
		if ($i % 100 == 0) {$print .= "\n$YW" . $i . "$N:\t";}
		if ($val[$i] =~ /[89]/) {
			$peak{beg} = $i if $peak{curr} == 0;
			$print .= "${LPR}$val[$i]$N" if $peak{curr} == 0;
			$print .= "${LRD}$val[$i]$N" if $peak{curr} == 1;
			$peak{curr} = 1;
		}
		elsif ($val[$i] =~ /[23]/) {
			$peak{end} = $i+1;
			push(@{$peak{peak}}, "$peak{beg}-$peak{end}");
			undef $peak{beg}; undef $peak{end};
			$peak{curr} = 0;
			$val[$i] =~ tr/23/89/;
			$print .= "${LPR}$val$N";
		}
		else {
			$print .= "EDGE1" if $i == $edge1;
			$print .= "${LGN}$val[$i]$N" if $val =~ /^[46]$/;
			$print .= "${LGN}$val[$i]$N" if $val =~ /^[57]$/;
			$print .= "." if $val[$i] eq 1;
			$print .= "x" if $val[$i] eq 0;# and $i < $edge1;
			$print .= "EDGE2" if $i == $edge2 - 1;
		}
	}
	$print .= "\n";
	print "$print" if $name_want eq $name;

	return ($name, \@val2, $totalpeak, $peak2{peak});
}

sub find_lots_of_C {
	my ($seqFile, $mygene, $outLog) = @_;#, $geneIndex, $box) = @_; #$geneIndexesFa;
	my %seq;
	LOG($outLog, date . "\n${YW}2. Parsing in sequence for genes from sequence file $CY$seqFile$N\n");
	open(my $SEQIN, "<", $seqFile) or LOG($outLog, date() . "\n$LRD!!!$N\tFATAL ERROR: Could not open $CY$seqFile$N: $!") and exit 1;
	my $fasta = new FAlite($SEQIN);
	my %lotsOfC;

	while (my $entry = $fasta->nextEntry()) {
	   my $gene = uc($entry->def); $gene =~ s/^>//;
	   my $seqz = uc($entry->seq);
		next if $gene ne $mygene;
	   LOG($outLog, date . "\t\tgenez=$gene ($gene)\n");
	   
	
		my $minlen = 6;
	   my $seqz2 = $seqz;#join("", @{$seq{$gene}{seq}});
	   while ($seqz2 =~ /(C){$minlen,99}/g) {
	      my ($prev, $curr, $next) = ($`, $&, $');
	      my ($curr_C) = length($curr);
	      my ($next_C) = $next =~ /^(C+)[AGTN]*$/;
	      $next_C = defined $next_C ? length($next_C) : 0;
	      my ($beg_C) = defined $prev ? length($prev) : 0;
	      my ($end_C) = $curr_C + $next_C + $beg_C;
	      my $length = $curr_C + $next_C;
	      ($prev) = $prev =~ /^.*(\w{$minlen})$/ if length($prev) > $minlen; $prev = "NA" if not defined $prev;
	      ($next) = $next =~ /^(\w{$minlen}).*$/ if length($next) > $minlen; $next = "NA" if not defined $next;
	      LOG($outLog, date() . "$gene: $beg_C to $end_C ($length)\n\tPREV=$prev\n\tCURR=$curr\n\tNEXT=$next\n");
	      $lotsOfC{$gene} .= "C;$beg_C;$end_C,";
	   }
		$seqz2 = "";
	   $seqz2 =$seqz;# join("", @{$seq{$gene}{seq}});
	   while ($seqz2 =~ /(G){$minlen,99}/g) {
	      my ($prev, $curr, $next) = ($`, $&, $');
	      my ($curr_G) = length($curr);
	      my ($next_G) = $next =~ /^(G+)[ACTN]*$/;
	      $next_G = defined $next_G ? length($next_G) : 0;
	      my ($beg_G) = defined $prev ? length($prev) : 0;
	      my ($end_G) = $curr_G + $next_G + $beg_G;
	      my $length = $curr_G + $next_G;
	      ($prev) = $prev =~ /^.*(\w{$minlen})$/ if length($prev) > $minlen; $prev = "NA" if not defined $prev;
	      ($next) = $next =~ /^(\w{$minlen}).*$/ if length($next) > $minlen; $next = "NA" if not defined $next;
	      LOG($outLog, date() . "$gene: $beg_G to $end_G ($length)\n\tPREV=$prev\n\tCURR=$curr\n\tNEXT=$next\n");
	      $lotsOfC{$gene} .= "G;$beg_G;$end_G,";
	   }
		my $bad;
		if (defined $lotsOfC{$gene}) {
			$lotsOfC{$gene} =~ s/,$//;
			my @lotsOfC = split(",", $lotsOfC{$gene});
			foreach my $coor (@lotsOfC) {
				my ($nuc, $beg, $end) = split(";", $coor);
				my $strands = $nuc eq "C" ? 0 : $nuc eq "G" ? 16 : 255;
				$bad->{$strands}{$beg} = $end-1;
				LOG($outLog, date() . "$strands: coor=$coor, nuc=$nuc, beg=$beg, end=$end, beg-end=$beg-$bad->{$strands}{$beg}\n");
			}
			return $bad;
		}
	}
	return;
}

1;

__END__
