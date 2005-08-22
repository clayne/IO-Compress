
use lib 't';
use strict;
local ($^W) = 1; #use warnings;
# use bytes;

use Test::More ;
use MyTestUtils;
use IO::File ;

BEGIN {
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 186 + $extra ;

    use_ok('Compress::Zlib', 2) ;
    use_ok('Compress::Gzip::Constants') ;

    use_ok('IO::Gzip', qw(gzip $GzipError)) ;
}


my $hello = <<EOM ;
hello world
this is a test
EOM

my $len   = length $hello ;

# Check zlib_version and ZLIB_VERSION are the same.
is Compress::Zlib::zlib_version, ZLIB_VERSION,
    "ZLIB_VERSION matches Compress::Zlib::zlib_version" ;
 
# gzip tests
#===========

my $name = "test.gz" ;
my ($x, $uncomp) ;

ok my $fil = gzopen($name, "wb") ;

is $gzerrno, 0, 'gzerrno is 0';
is $fil->gzerror(), 0, "gzerror() returned 0";

is $fil->gztell(), 0, "gztell returned 0";
is $gzerrno, 0, 'gzerrno is 0';

is $fil->gzwrite($hello), $len ;
is $gzerrno, 0, 'gzerrno is 0';

is $fil->gztell(), $len, "gztell returned $len";
is $gzerrno, 0, 'gzerrno is 0';

ok ! $fil->gzclose ;

ok $fil = gzopen($name, "rb") ;

ok ! $fil->gzeof() ;
is $gzerrno, 0, 'gzerrno is 0';
is $fil->gztell(), 0;

is $fil->gzread($uncomp), $len; 

is $fil->gztell(), $len;
ok   $fil->gzeof() ;
ok ! $fil->gzclose ;
ok   $fil->gzeof() ;

unlink $name ;

ok $hello eq $uncomp ;

# check that a number can be gzipped
my $number = 7603 ;
my $num_len = 4 ;

ok $fil = gzopen($name, "wb") ;

is $gzerrno, 0;

is $fil->gzwrite($number), $num_len, "gzwrite returned $num_len" ;
is $gzerrno, 0, 'gzerrno is 0';
ok $fil->gzflush(Z_FINISH) ;

is $gzerrno, 0, 'gzerrno is 0';

ok ! $fil->gzclose ;

cmp_ok $gzerrno, '==', 0;

ok $fil = gzopen($name, "rb") ;

ok (($x = $fil->gzread($uncomp)) == $num_len) ;

ok $fil->gzerror() == 0 || $fil->gzerror() == Z_STREAM_END;
ok $gzerrno == 0 || $gzerrno == Z_STREAM_END;
ok   $fil->gzeof() ;

ok ! $fil->gzclose ;
ok   $fil->gzeof() ;

ok $gzerrno == 0
    or print "# gzerrno is $gzerrno\n" ;

unlink $name ;

ok $number == $uncomp ;
ok $number eq $uncomp ;


# now a bigger gzip test

my $text = 'text' ;
my $file = "$text.gz" ;

ok my $f = gzopen($file, "wb") ;

# generate a long random string
my $contents = '' ;
foreach (1 .. 5000)
  { $contents .= chr int rand 256 }

$len = length $contents ;

ok $f->gzwrite($contents) == $len ;

ok ! $f->gzclose ;

ok $f = gzopen($file, "rb") ;
 
ok ! $f->gzeof() ;

my $uncompressed ;
is $f->gzread($uncompressed, $len), $len ;

ok $contents eq $uncompressed 

    or print "# Length orig $len" . 
             ", Length uncompressed " . length($uncompressed) . "\n" ;

ok $f->gzeof() ;
ok ! $f->gzclose ;

unlink($file) ;

# gzip - readline tests
# ======================

# first create a small gzipped text file
$name = "test.gz" ;
my @text = (<<EOM, <<EOM, <<EOM, <<EOM) ;
this is line 1
EOM
the second line
EOM
the line after the previous line
EOM
the final line
EOM

$text = join("", @text) ;

ok $fil = gzopen($name, "wb") ;
ok $fil->gzwrite($text) == length $text ;
ok ! $fil->gzclose ;

# now try to read it back in
ok $fil = gzopen($name, "rb") ;
ok ! $fil->gzeof() ;
my $line = '';
for my $i (0 .. @text -2)
{
    ok $fil->gzreadline($line) > 0;
    ok $line eq $text[$i] ;
    ok ! $fil->gzeof() ;
}

# now read the last line
ok $fil->gzreadline($line) > 0;
ok $line eq $text[-1] ;
ok $fil->gzeof() ;

# read past the eof
is $fil->gzreadline($line), 0;

ok   $fil->gzeof() ;
ok ! $fil->gzclose ;
ok   $fil->gzeof() ;
unlink($name) ;

# a text file with a very long line (bigger than the internal buffer)
my $line1 = ("abcdefghijklmnopq" x 2000) . "\n" ;
my $line2 = "second line\n" ;
$text = $line1 . $line2 ;
ok $fil = gzopen($name, "wb") ;
ok $fil->gzwrite($text) == length $text ;
ok ! $fil->gzclose ;

# now try to read it back in
ok $fil = gzopen($name, "rb") ;
ok ! $fil->gzeof() ;
my $i = 0 ;
my @got = ();
while ($fil->gzreadline($line) > 0) {
    $got[$i] = $line ;    
    ++ $i ;
}
ok $i == 2 ;
ok $got[0] eq $line1 ;
ok $got[1] eq $line2 ;

ok   $fil->gzeof() ;
ok ! $fil->gzclose ;
ok   $fil->gzeof() ;

unlink $name ;

# a text file which is not termined by an EOL

$line1 = "hello hello, I'm back again\n" ;
$line2 = "there is no end in sight" ;

$text = $line1 . $line2 ;
ok $fil = gzopen($name, "wb") ;
ok $fil->gzwrite($text) == length $text ;
ok ! $fil->gzclose ;

# now try to read it back in
ok $fil = gzopen($name, "rb") ;
@got = () ; $i = 0 ;
while ($fil->gzreadline($line) > 0) {
    $got[$i] = $line ;    
    ++ $i ;
}
ok $i == 2 ;
ok $got[0] eq $line1 ;
ok $got[1] eq $line2 ;

ok   $fil->gzeof() ;
ok ! $fil->gzclose ;

unlink $name ;

{

    title 'mix gzread and gzreadline';
    
    # case 1: read a line, then a block. The block is
    #         smaller than the internal block used by
    #	  gzreadline
    my $name = "test.gz" ;
    my $lex = new LexFile $name ;
    $line1 = "hello hello, I'm back again\n" ;
    $line2 = "abc" x 200 ; 
    my $line3 = "def" x 200 ;
    
    $text = $line1 . $line2 . $line3 ;
    ok $fil = gzopen($name, "wb"), ' gzopen for write ok' ;
    is $fil->gzwrite($text), length $text, '    gzwrite ok' ;
    is $fil->gztell(), length $text, '    gztell ok' ;
    ok ! $fil->gzclose, '  gzclose ok' ;
    
    # now try to read it back in
    ok $fil = gzopen($name, "rb"), '  gzopen for read ok' ;
    ok ! $fil->gzeof(), '    !gzeof' ;
    cmp_ok $fil->gzreadline($line), '>', 0, '    gzreadline' ;
    is $fil->gztell(), length $line1, '    gztell ok' ;
    ok ! $fil->gzeof(), '    !gzeof' ;
    is $line, $line1, '    got expected line' ;
    cmp_ok $fil->gzread($line, length $line2), '>', 0, '    gzread ok' ;
    is $fil->gztell(), length($line1)+length($line2), '    gztell ok' ;
    ok ! $fil->gzeof(), '    !gzeof' ;
    is $line, $line2, '    read expected block' ;
    cmp_ok $fil->gzread($line, length $line3), '>', 0, '    gzread ok' ;
    is $fil->gztell(), length($text), '    gztell ok' ;
    ok   $fil->gzeof(), '    !gzeof' ;
    is $line, $line3, '    read expected block' ;
    ok ! $fil->gzclose, '  gzclose'  ;
}

{
    title "Pass gzopen a filehandle" ;

    my $name = "test.gz" ;
    my $lex = new LexFile $name ;

    my $hello = "hello" ;
    my $len = length $hello ;

    unlink $name ;

    my $f = new IO::File ">$name" ;
    ok $f;

    ok my $fil = gzopen($f, "wb") ;

    ok $fil->gzwrite($hello) == $len ;

    ok ! $fil->gzclose ;

    $f = new IO::File "<$name" ;
    ok $fil = gzopen($name, "rb") ;

    my $uncmomp;
    ok (($x = $fil->gzread($uncomp)) == $len) 
        or print "# length $x, expected $len\n" ;

    ok   $fil->gzeof() ;
    ok ! $fil->gzclose ;
    ok   $fil->gzeof() ;

    unlink $name ;

    ok $hello eq $uncomp ;


}

{
    title "Pass gzopen a filehandle" ;

    my $name = "test.gz" ;
    my $lex = new LexFile $name ;

    my $hello = "hello" ;
    my $len = length $hello ;

    unlink $name ;

    open F, ">$name" ;

    ok my $fil = gzopen(*F, "wb") ;

    is $fil->gzwrite($hello), $len ;

    ok ! $fil->gzclose ;

    open F, "<$name" ;
    ok $fil = gzopen(*F, "rb") ;

    my $uncmomp;
    $x = $fil->gzread($uncomp);
    is $x, $len ;

    ok   $fil->gzeof() ;
    ok ! $fil->gzclose ;
    ok   $fil->gzeof() ;

    unlink $name ;

    ok $hello eq $uncomp ;


}
{
    title 'test parameters for gzopen';
    my $name = "test.gz" ;
    my $lex = new LexFile $name ;

    my $fil;

    unlink $name ;

    # missing parameters
    eval ' $fil = gzopen()  ' ;
    like $@, mkEvalErr('Not enough arguments for Compress::Zlib::gzopen'),
        '  gzopen with missing mode fails' ;

    # unknown parameters
    $fil = gzopen($name, "xy") ;
    ok ! defined $fil, '  gzopen with unknown mode fails' ;

    $fil = gzopen($name, "ab") ;
    ok $fil, '  gzopen with mode "ab" is ok' ;

    $fil = gzopen($name, "wb6") ;
    ok $fil, '  gzopen with mode "wb6" is ok' ;

    $fil = gzopen($name, "wbf") ;
    ok $fil, '  gzopen with mode "wbf" is ok' ;

    $fil = gzopen($name, "wbh") ;
    ok $fil, '  gzopen with mode "wbh" is ok' ;
}

{
    title 'Read operations when opened for writing';

    my $name = "test.gz" ;
    my $lex = new LexFile $name ;
    ok $fil = gzopen($name, "wb"), '  gzopen for writing' ;
    ok !$fil->gzeof(), '    !eof'; ;
    is $fil->gzread(), Z_STREAM_ERROR, "    gzread returns Z_STREAM_ERROR" ;
}

{
    title 'write operations when opened for reading';

    my $name = "test.gz" ;
    my $lex = new LexFile $name ;
    my $test = "hello" ;
    ok $fil = gzopen($name, "wb"), "  gzopen for writing" ;
    is $fil->gzwrite($text), length $text, "    gzwrite ok" ;
    ok ! $fil->gzclose, "  gzclose ok" ;

    ok $fil = gzopen($name, "rb"), "  gzopen for reading" ;
    is $fil->gzwrite(), Z_STREAM_ERROR, "  gzwrite returns Z_STREAM_ERROR" ;
}

{
    title 'read/write a non-readable/writable file';

    my $name = "test.gz" ;
    my $lex = new LexFile $name ;
    writeFile($name, "abc");
    chmod 0, $name ;

    ok ! -w $name, "  input file not writable";

    my $fil = gzopen($name, "wb") ;
    ok !$fil, "  gzopen returns undef" ;
    ok $gzerrno, "  gzerrno ok" or 
        diag " gzerrno $gzerrno\n";

    SKIP:
    {
        skip "Cannot create non-readable file",3 if -r $name ;

        ok ! -r $name, "  input file not readable";
        $gzerrno = 0;
        $fil = gzopen($name, "rb") ;
        ok !$fil, "  gzopen returns undef" ;
        ok $gzerrno, "  gzerrno ok";
    }

    chmod 0777, $name ;
}

{
    title "gzseek" ;

    my $buff ;
    my $name = "test.gz" ;
    my $lex = new LexFile $name ;

    my $first = "beginning" ;
    my $last  = "the end" ;
    my $iow = gzopen($name, "w");
    $iow->gzwrite($first) ;
    ok $iow->gzseek(5, SEEK_CUR) ;
    is $iow->gztell(), length($first)+5;
    ok $iow->gzseek(0, SEEK_CUR) ;
    is $iow->gztell(), length($first)+5;
    ok $iow->gzseek(length($first)+10, SEEK_SET) ;
    is $iow->gztell(), length($first)+10;

    $iow->gzwrite($last) ;
    $iow->gzclose ;

    ok GZreadFile($name) eq $first . "\x00" x 10 . $last ;

    my $io = gzopen($name, "r");
    ok $io->gzseek(length($first), SEEK_CUR) ;
    ok ! $io->gzeof;
    is $io->gztell(), length($first);

    ok $io->gzread($buff, 5) ;
    is $buff, "\x00" x 5 ;
    is $io->gztell(), length($first) + 5;

    is $io->gzread($buff, 0), 0 ;
    #is $buff, "\x00" x 5 ;
    is $io->gztell(), length($first) + 5;

    ok $io->gzseek(0, SEEK_CUR) ;
    my $here = $io->gztell() ;
    is $here, length($first)+5;

    ok $io->gzseek($here+5, SEEK_SET) ;
    is $io->gztell(), $here+5 ;
    ok $io->gzread($buff, 100) ;
    ok $buff eq $last ;
    ok $io->gzeof;
}

{
    # seek error cases
    my $name = "test.gz" ;
    my $lex = new LexFile $name ;

    my $a = gzopen($name, "w");

    ok ! $a->gzerror() 
        or print "# gzerrno is $Compress::Zlib::gzerrno \n" ;
    eval { $a->gzseek(-1, 10) ; };
    like $@, mkErr("gzseek: unknown value, 10, for whence parameter");

    eval { $a->gzseek(-1, SEEK_END) ; };
    like $@, mkErr("gzseek: cannot seek backwards");

    $a->gzwrite("fred");
    $a->gzclose ;


    my $u = gzopen($name, "r");

    eval { $u->gzseek(-1, 10) ; };
    like $@, mkErr("gzseek: unknown value, 10, for whence parameter");

    eval { $u->gzseek(-1, SEEK_END) ; };
    like $@, mkErr("gzseek: SEEK_END not allowed");

    eval { $u->gzseek(-1, SEEK_CUR) ; };
    like $@, mkErr("gzseek: cannot seek backwards");
}
