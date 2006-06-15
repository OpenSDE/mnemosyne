#!/usr/bin/perl
# --- T2-COPYRIGHT-NOTE-BEGIN ---
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# 
# T2 SDE: target/mnemosyne/mnemosyne.pl
# Copyright (C) 2004 - 2006 The T2 SDE Project
# 
# More information can be found in the files COPYING and README.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License. A copy of the
# GNU General Public License can be found in the file COPYING.
# --- T2-COPYRIGHT-NOTE-END ---

use warnings;
use strict;
use IPC::Open2;

use constant {ALL => 0, ASK => 1, CHOICE => 2 };
%::FOLDER=();
%::MODULE=();

sub scandir {
	my ($pkgseldir,$prefix) = @_;
	my %current=('location', $pkgseldir, 'var', "CFGTEMP_$prefix");

	# $current{desc,var} for sub-pkgsel dirs
	if ($pkgseldir ne $::ROOT) {
		my ($relative,$dirvar,$dirname);
		$_ = $pkgseldir;
		$relative = (m/^$::ROOT\/(.*)/i)[0];

		$dirvar =  "CFGTEMP_$prefix\_$relative";
		$dirvar =~ tr,a-z\/ ,A-Z__,;

		$dirname=$relative;
		$dirname=~ s/.*\///g;

		$current{desc} = $dirname;
		$current{var}  = $dirvar;
	}

	# make this folder global
	$::FOLDER{$current{var}} = \%current;

	{
	# make scandir recursive
	my @children;
	opendir(my $DIR, $pkgseldir);
	foreach( grep { ! /^\./ } sort readdir($DIR) ) {
		$_ = "$pkgseldir/$_";
		if ( -d $_ ) {
			my $subdir = scandir($_,$prefix);
			push @children,$subdir;
		} else {
			my $module=scanmodule($_,$prefix,$current{var});
			if ($module) {
				push @children,$module unless grep(/^$module$/,@children);
				}
		}
	}
        closedir $DIR;
	$current{children} = \@children;
	return $current{var};
	}

}

sub scanmodule {
	my ($file,$prefix,$folder)=@_;
	my (%current,$FILE);

	# this defines dir,key,option and kind acording to the following format.
	# $dir/[$prio-]$var[$option].$kind
	do {
		my ($dir,$key,$option,$kind);
		m/^(.*)\/(\d+-)?([^\.]*).?([^\.]*)?\.([^\/\.]*)/i;
		($dir,$key,$option,$kind) = ($1,$3,$4,$5);

		if ($kind eq 'choice') { $current{kind} = CHOICE; $current{option} = $option; }
		elsif ($kind eq 'all') { $current{kind} = ALL; }
		elsif ($kind eq 'ask') { $current{kind} = ASK; }
		else { return; }

		$current{location} = $dir;
		$current{key} = $key;
		$current{file} = $file;
	
	} for $file;

	open($FILE,'<',$file);
	while(<$FILE>) {
		if (/^#[^#: ]+: /) {
			my ($field,$value) = m/^#([^#: ]+): (.*)$/i;
			if ($field eq 'Description') {
				$current{desc} = $value;
			} elsif ($field eq 'Variable') {
				$current{var} = $value;
			} elsif ($field eq 'Default') {
				$current{default} = $value;
			} elsif ($field eq 'Forced') {
				$current{forced} = $value;
			} elsif ($field eq 'Imply') {
				$current{imply} = $value;
			} elsif ($field eq 'Dependencies') {
				$current{deps} = $value;
		#	} else {
		#		print "$file:$field:$value.\n";
				}
			}
		}
	close($FILE);

	# var name
	$current{var} = uc $current{key}
		unless exists $current{var};
	$current{var} = "SDECFG_$prefix\_" . $current{var}
		unless $current{var} =~ /^SDECFG_$prefix\_/;

	# for choices, we use $option instead of $key as description
	($current{desc} = $current{option}) =~ s/_/ /g
		if exists $current{option} && ! exists $current{desc};
	($current{desc} = $current{key}) =~ s/_/ /g
		unless exists $current{desc};

	# dependencies
	# NOTE: don't use spaces on the pkgsel file, only to delimite different dependencies
	if (exists $current{deps}) {
		my @deps;
		for ( split (/\s+/,$current{deps}) ) {
			$_="SDECFG_$prefix\_$_" unless /^SDECFG/;

			if (/=/) {
				m/(.*?)(==|!=|=)(.*)/i;
				$_="\"\$$1\" $2 $3";
			} else {
				$_="\"\$$_\" == 1";
				}

			push @deps,$_;
			}
		$current{deps} = \@deps;
		}

	# forced modules
	if (exists $current{forced}) {
		my @forced;
		for ( split (/\s+/,$current{forced}) ) {
			$_="SDECFG_$prefix\_$_" unless /^SDECFG/;

			$_="$_=1" unless /=/;
			push @forced,$_;
			}
		$current{forced} = \@forced;
		}
	
	# implied options
	if (exists $current{imply}) {
		my @imply = split (/\s+/,$current{imply});
		$current{imply} = \@imply;
		}

	# make this module global
	if ( $current{kind} == CHOICE ) {

		# prepare the option for this choice
		my %option;
		for ('desc','forced','imply','deps','option','file') {
			$option{$_}=$current{$_} if exists $current{$_};
			}

		if ( exists $::MODULE{$current{var}} ) {
			push @{ $::MODULE{$current{var}}{options} },\%option;
		} else {
			# prepare and add this choice module
			my @options = (\%option);

			$::MODULE{$current{var}} = {
				'kind', CHOICE,
				'options', \@options,
				};

			for ('key','location','var') {
				$::MODULE{$current{var}}{$_}=$current{$_}
					if exists $current{$_};
				}
			}

	} else {
		$::MODULE{$current{var}} = {};
		for ('key','location','var','desc','forced','deps','file','kind') {
			$::MODULE{$current{var}}{$_}=$current{$_}
				if exists $current{$_};
			}
		}

	# default value
	$::MODULE{$current{var}}{folder}  = $folder;
	$::MODULE{$current{var}}{default} = $current{default} 
		if exists $current{default};

	return $current{var};
	}
	
sub process_modules { 
	my ($READ,$WRITE,$pid);
	my $i=0;

	$pid = open2($READ, $WRITE, 'tsort');
	# prepare topographic modules map
	for my $module (values %::MODULE) { 
		my $related;

		if ($module->{kind} == CHOICE) {
			for (@{ $module->{options} }) {
				my $option = $_;
				for (@{exists $option->{deps} ? $option->{deps} : []} ) {
					my $dep = (m/"\$([^"]+)"/i)[0];
					print $WRITE "$dep $module->{var}\n";
					$related=1;
				}
				for (@{exists $option->{forced} ? $option->{forced} : []} ) {
					my $forced = (m/([^"]+)=/i)[0];
					print $WRITE "$module->{var} $forced\n";
					$related=1;
					}
				}
		} else {
			for (@{exists $module->{deps} ? $module->{deps} : []} ) {
				my $dep = (m/"\$([^"]+)"/i)[0];
				print $WRITE "$dep $module->{var}\n";
				$related=1;
				}
			for (@{exists $module->{forced} ? $module->{forced} : []} ) {
				my $forced = (m/([^"]+)=/i)[0];
				print $WRITE "$module->{var} $forced\n";
				$related=1;
				}
			}

		if (! $related) {
			print $WRITE "$module->{var} $module->{var}\n";
			}
		}

	close($WRITE);

	# and populate the sorted list
	my @sorted;
	while(<$READ>) {
		if (/(.*)\n/) { push @sorted, $1; }
		}

	waitpid $pid,0;
	die if $?;

	# and remember the sorted list
	$::MODULES=\@sorted;
}

sub process_folders { 
	my ($READ,$WRITE,$pid);

	$pid = open2($READ, $WRITE, 'tsort | tac');
	# prepare topographic modules map
	for my $folder (values %::FOLDER) { 
		for ( exists $folder->{children} ? grep(!/^SDECFG/, @{$folder->{children}}) : [] ) {
			print $WRITE "$folder->{var} $_\n";
			}
		}
	close($WRITE);

	# and populate the sorted list
	my @sorted;
	while(<$READ>) {
		if (/(.*)\n/) { push @sorted, $1; }
		}

	waitpid $pid,0;
	die if $?;

	# and remember the sorted list
	$::FOLDERS=\@sorted;
}

sub render_widgets_folder {
	my ($folder,$offset) = @_;
	for (@{$folder->{children}}) {
		if (/^CFGTEMP/) {
			my $subfolder=$::FOLDER{$_};
			print "\n${offset}# $_\n${offset}#\n";

			# opening
			print "${offset}if [ \"\$$subfolder->{var}\" == 1 ]; then\n";
			print "${offset}\tmenu_begin $subfolder->{var} '$subfolder->{desc}'\n";
			print "${offset}fi\n";

			render_widgets_folder($::FOLDER{$_},"$offset\t");

			# closing
			print "${offset}if [ \"\$$subfolder->{var}\" == 1 ]; then\n";
			print "${offset}\tmenu_end\n";
			print "${offset}fi\n";
		} else {
			my $module=$::MODULE{$_};
			my $var=$module->{var};
			my $conffile="$module->{location}/$module->{key}.conf"
				if -f "$module->{location}/$module->{key}.conf";
			my $noconffile="$module->{location}/$module->{key}-no.conf"
				if -f "$module->{location}/$module->{key}-no.conf";

			print "${offset}# $var\n";

			if ($module->{kind} == CHOICE) {
				# CHOICE
				my $tmpvar = "CFGTEMP_$1" if $var =~ m/^SDECFG_(.*)/i;
				my $listvar = "$tmpvar\_LIST";
				my $defaultvar = "$tmpvar\_DEFAULT";

				print "${offset}if \[ -n \"\$$var\" \]; then\n";
				print "${offset}\tchoice $var \$$defaultvar \$$listvar\n";
				print "${offset}\t. $conffile\n" if $conffile;
				print "${offset}\telse\n" if $noconffile;
				print "${offset}\t. $noconffile\n" if $noconffile;
				print "${offset}fi\n";

			} elsif ($module->{kind} == ASK) {
				# ASK
				my $default=0;
				$default = $module->{default} if exists $module->{default};

				print "${offset}if \[ -n \"\$$var\" \]; then\n";
				print "${offset}\tbool '$module->{desc}' $module->{var} $default\n";
				print "${offset}\t\[ \"\$$var\" == 1 \] && . $conffile\n" if $conffile;
				print "${offset}\t\[ \"\$$var\" != 1 \] && . $noconffile\n" if $noconffile;
				print "${offset}fi\n";
			} elsif ($conffile) {
				# ALL, only if $conffile
				print "${offset}if \[ -n \"\$$var\" \]; then\n";
				print "${offset}\t. $conffile\n" if $conffile;
				print "${offset}\telse\n" if $noconffile;
				print "${offset}\t. $noconffile\n" if $noconffile;
				print "${offset}fi\n";
				}
			}
		}
	}
sub render_widgets {
	open(my $FILE,'>',$_[0]);
	my $root="CFGTEMP_$_[1]";

	select $FILE;
	render_widgets_folder($::FOLDER{$root},'');
	select STDOUT;
	close($FILE);
	}

sub pkgsel_parse {
	my ($action,$patternlist) = @_;
	if ($action eq 'X' or $action eq 'x' ) {
		$action = '$1="X"';
	} elsif ($action eq 'O' or $action eq 'o') {
		$action = '$1="O"';
	} elsif ($action eq '-') {
		$action = 'next';
	} else {
		$action = '{ exit; }';
		}

	my ($address,$first,$others)= ('','( ','&& ');

	for (split(/\s+/,$patternlist)) {
		if (! $address and $_ eq '!') {
			$address = '! ';
			$others  = '|| $4"/"$5 ~';
		} else {
			$_="\*/$_" unless /\//;
			s,[^a-zA-Z0-9_/\*+\.-],,g;
			s,([/\.\+]),\\$1,g;
			s,\*,[^/]*,g;
			next unless $_;
			$address = "$address$first";
			$address = "$address / $_ /";
			$first   = "$others";
			}
			
=for nobody
				[ "$pattern" ] || continue
				address="$address$first"
				address="$address / $pattern /"
				first=" $others"

=cut
		}

	print "\techo '$address ) { $action; }'\n";
	return 1;
}

sub render_awkgen {
	open(my $OUTPUT,'>',$_[0]);
	my $root="CFGTEMP_$_[1]";

	select $OUTPUT;

	# initially change packages $4 and $5 to be able to correctly match repo based.
	print "echo '{'\n";
	print "echo '\trepo=\$4 ;'\n";
	print "echo '\tpkg=\$5 ;'\n";
	print "echo '\t\$5 = \$4 \"/\" \$5 ;'\n";
	print "echo '\t\$4 = \"placeholder\" ;'\n";
	print "echo '}'\n";

	render_awkgen_folder($::FOLDER{$root});

	# ... restore $4 and $5, and print the resulting line
	print "echo '\n{'\n";
	print "echo '\t\$4=repo ;'\n";
	print "echo '\t\$5=pkg ;'\n";
	print "echo '\tprint ;'\n";
	print "echo '}'\n";

	select STDOUT;
	close($OUTPUT);
	}

sub render_awkgen_folder {
	my ($folder) = @_;
	for (@{$folder->{children}}) {
		if (/^CFGTEMP/) {
			render_awkgen_folder($::FOLDER{$_});
		} else {
		my $module=$::MODULE{$_};
		if ($module->{kind} == CHOICE) {
			my %options;

			# the list of options
			for (@{ $module->{options} }) {
				my $option = $_;
				my @array=("\"\$$module->{var}\" == $_->{option}");
				$options{$_->{option}} = \@array;
				}
			# and their implyed options
			for (@{ $module->{options} }) {
				my $option = $_;
				for (@{exists $option->{imply}? $option->{imply} : [] }) {
					push @{$options{$_}},
						"\"\$$module->{var}\" == $option->{option}";
					}
				}

			print "\n";
			# and finally, render.
			for (@{ $module->{options} }) {
				print "if [ " . join(' -o ',@{ $options{ $_->{option} }}). " ]; then\n";

				open(my $FILE,'<',$_->{file});
				my $hasrules=0;
				while(<$FILE>) {
					next if /^#/;
					next if /^\s*$/;
					pkgsel_parse($1,$2) if m/^([^\s]+)\s+(.*)\s*\n?$/i;
					$hasrules=1;
				}
				close($FILE);
				print "\ttrue\n" unless $hasrules;

				print "fi\n";
				}
		} else {
			print "\nif [ \"\$$module->{var}\" == 1 ]; then\n";
				open(my $FILE,'<',$module->{file});
				my $hasrules=0;
				while(<$FILE>) {
					next if /^#/;
					next if /^\s*$/;
					pkgsel_parse($1,$2) if m/^([^\s]+)\s+(.*)\s*\n?$/i;
					$hasrules=1;
					}
				close($FILE);
				print "\ttrue\n" unless $hasrules;
			print "fi\n";
			}
		}
		}
	}
	
sub render_rules_module {
	my ($module,$offset) = @_;
	my $var    = $module->{var};

	if ($module->{kind} == CHOICE) {
		my $tmpvar = "CFGTEMP_$1" if $var =~ m/^SDECFG_(.*)/i;
		my $listvar = "$tmpvar\_LIST";
		my $defaultvar = "$tmpvar\_DEFAULT";
		my $default = "undefined";
		my $forcer;

		$default = $module->{default} if exists $module->{default};

		# initialize the list
		print "${offset}$listvar=\n";
		
		print "${offset}$defaultvar=$default\n";
		print "${offset}\[ -n \"\$$var\" \] || $var=$default\n\n";

		for ( @{ $module->{options} } ) {
			my $option = $_;
			(my $desc = $option->{desc}) =~ s/ /_/g;

			# has something to force?
			if (exists $option->{forced}) { $forcer = 1; }

			if (exists $option->{deps}) {
				print "${offset}if [ " .
					join(' -a ', @{ $option->{deps} } ) .
					" ]; then\n";
				print "${offset}\t$listvar=\"\$$listvar $option->{option} $desc\"\n";
				print "${offset}fi\n";
			} else {
				print "${offset}$listvar=\"\$$listvar $option->{option} $desc\"\n";
				}
			}

		# enable the folder display
		print "${offset}if \[ -n \"\$$listvar\" \]; then\n";
		print "${offset}\t$module->{folder}=1\n";
		print "${offset}else\n";
		print "${offset}\tunset $module->{var}\n";
		print "${offset}fi\n";
		
		# has something to force?
		if ($forcer) {
			print "\n${offset}case \"\$$var\" in\n";
			for ( @{ $module->{options} } ) {
				my $option = $_;
				if (exists $option->{forced}) {
					print "${offset}\t$option->{option})\n";
					for ( @{ $option->{forced} } ) {
						print "$offset\t\t$_\n";
						print "$offset\t\tSDECFGSET_$1\n" if $_ =~ m/^SDECFG_(.*)/i;
						}
					print "${offset}\t\t;;\n";
					}
				}
			print "${offset}esac\n";
			}
		
	#	printref($var,$module,$offset);
	} elsif ($module->{kind} == ASK) {
		my $default=0;
		$default = $module->{default} if exists $module->{default};

		#enable the folder display
		print "$offset$module->{folder}=1\n";

		# and set the default value if none is set.
		print "$offset\[ -n \"\$$var\" \] || $var=$default\n";

		# if enabled, append pkgsel and force the forced

		if (exists $module->{forced}) {
			print "\n${offset}if [ \"\$$var\" == 1 ]; then\n";
			for ( @{ $module->{forced} } ) {
				print "$offset\t$_\n";
				print "$offset\tSDECFGSET_$1\n" if $_ =~ m/^SDECFG_(.*)/i;
				}
			print $offset."fi\n";
			}
	} else {
		# just enable the feature
		print "$offset$var=1\n";

		# forced list doesn't make sense for {kind} == ALL
		}

	}
sub render_rules_nomodule {
	my ($module,$offset) = @_;
	my $var = $module->{var};

	# unset the choice list, and the var
	if ($module->{kind} == CHOICE) {
		my $listvar = "CFGTEMP_$1_LIST" if $var =~ m/^SDECFG_(.*)/i;
		print "${offset}unset $listvar\n";
		}
	print "${offset}unset SDECFGSET_$1\n" if $var =~ m/^SDECFG_(.*)/i;
	print "${offset}unset $var\n";
	}

sub render_rules {
	open(my $FILE,'>',$_[0]);
	my $root="CFGTEMP_$_[1]";
	select $FILE;

	# clean folder enablers
	print "#\n# folder enablers\n#\n\n";
	for (@$::FOLDERS) { print "$_=\n" unless /^$root$/; }

	# pkgsel list
	for (@$::MODULES) {
		if (exists $::MODULE{$_}) {
		my $module = $::MODULE{$_};
		print "\n#\n# $module->{var} ("
			. ($module->{kind} == ALL ? "ALL" : ($module->{kind} == ASK ? "ASK" : "CHOICE" ) )
			.  ")\n#\n";

		
		if (exists $module->{deps}) {
			print "if [ " . join(' -a ', @{ $module->{deps} } ) . " ]; then\n";
			render_rules_module($module,"\t");
			print "else\n";
			render_rules_nomodule($module,"\t");
			print "fi\n";
		} else {
			render_rules_module($module,"");
			}
		}
		}

	print "\n#\n# enable folder with enabled subfolders\n#\n";
	for (@$::FOLDERS) {
		my $folder = $::FOLDER{$_};
		my @subdirs = grep(/^CFGTEMP/,@{$folder->{children}});
		if ( @subdirs ) {
			print "if [ -n \"\$".join('$', @subdirs )."\" ]; then\n";
			print "\t$folder->{var}=1\n";
			print "fi\n";
			}
		}

	select STDOUT;
	close($FILE);
	}
	
# print the content of a hash
sub printref {
	my ($name,$ref,$offset) = @_;
	my $typeof = ref($ref);

	print "$offset$name:";
	if ($typeof eq '') {
		print " '$ref'\n";
	} elsif ($typeof eq 'HASH') {
		print "\n";
		for (sort keys %{ $ref }) {
			printref($_,$ref->{$_},"$offset\t");
			}
	} elsif ($typeof eq 'ARRAY') {
		my $i=0;
		print "\n";
		for (@{ $ref }) {
			printref("[$i]",$_,"$offset\t");
			$i++;
		}
	} else {
		print " -> $typeof\n";
		}
}

if ($#ARGV != 4) {
	print "Usage mnemosyne.pl: <pkgseldir> <prefix> <configfile> <rulesfile> <awkgenerator>\n";
	exit (1);
	}

$| = 1;

$::ROOT=$ARGV[0];
scandir($ARGV[0],$ARGV[1]);
process_modules();
process_folders();
render_rules($ARGV[3],$ARGV[1]);
render_widgets($ARGV[2],$ARGV[1]);
render_awkgen($ARGV[4],$ARGV[1]);
