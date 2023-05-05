
sub build_header {
  system("ruby ./prep.rb")
}

build_header()


$success_cmd = 'cat paper.log';
$failure_cmd = 'cat paper.log';
