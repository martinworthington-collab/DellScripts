#!/usr/bin/perl 

$Target_Path = shift @ARGV;
$Number = shift @ARGV;
$Increment_Amount = shift @ARGV;
$New_Prefix = shift @ARGV;
$New_Suffix = shift @ARGV;
$Skip_String = shift @ARGV;

@Entered_Skips = split / /, $Skip_String;

for $Skip (@Entered_Skips) {
  if ($Skip =~ m/(\d+)-(\d+)/) {
    for $i ($1..$2) {push @Skip_List, $i}
  }
  else {push @Skip_List, $Skip}
}

chdir $Target_Path or die "Invalid path";

@files = glob "*";
while ($file = shift @files) {
  $Output_Suffix = $New_Suffix;
  unless ($Output_Suffix) {
    # Hacked to handle the special case of _puz.PDF "extensions"
    $Output_Suffix = "$1$2" if ($file =~ m/(_puz|_sol)*(\.[^.]+)$/);
  }
  $New_Name = sprintf "%s%03d%s", $New_Prefix, $Number, $Output_Suffix;
  rename $file, $New_Name unless -e $New_Name;
  $Number += $Increment_Amount;
  
  while (grep m/^($Number)$/, @Skip_List) {$Number += $Increment_Amount;}
}
