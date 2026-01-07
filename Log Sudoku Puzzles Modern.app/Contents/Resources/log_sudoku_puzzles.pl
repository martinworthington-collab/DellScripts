#!/usr/bin/env perl
use strict;
use warnings;

# Extracts Sudoku grids from Dell-style .Large files written by the generator.
# Prints one line per puzzle with spaces replaced by 0 so it stays 81 chars.

die "Usage: $0 <file1.Large> [file2.Large ...]\n" unless @ARGV;

for my $file (@ARGV) {
    open my $fh, "<", $file or die "Can't open $file: $!\n";
    my $puzzle = "";
    while (my $line = <$fh>) {
        if ($line =~ /^box 0 \((.+)\)/) {
            $puzzle .= $1;
        }
    }
    close $fh;
    $puzzle =~ s/ /0/g;
    print "$puzzle\n";
}
