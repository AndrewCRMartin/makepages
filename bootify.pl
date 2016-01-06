#!/usr/bin/perl -s
#*************************************************************************
#
#   Program:    bootify
#   File:       bootify.pl
#   
#   Version:    V1.2
#   Date:       05.01.16
#   Function:   Create a (set of) HTML page(s) using attractive 
#               Bootstrap layout from very simple HTML meta-markup
#               So this beautifies and boostrapifies the pages
#   
#   Copyright:  (c) Dr. Andrew C. R. Martin, UCL, 2015-2016
#   Author:     Dr. Andrew C. R. Martin
#   Address:    Institute of Structural and Molecular Biology
#               Division of Biosciences
#               University College
#               Gower Street
#               London
#               WC1E 6BT
#   EMail:      andrew@bioinf.org.uk
#               
#*************************************************************************
#
#   This program is not in the public domain, but it may be copied
#   according to the conditions laid out in the accompanying file
#   COPYING.DOC
#
#   The code may be modified as required, but any modifications must be
#   documented so that the person responsible can be identified. If 
#   someone else breaks this code, I don't want to be blamed for code 
#   that does not work! 
#
#   The code may not be sold commercially or included as part of a 
#   commercial product except as described in the file COPYING.DOC.
#
#*************************************************************************
#
#   Description:
#   ============
#
#*************************************************************************
#
#   Usage:
#   ======
#
#*************************************************************************
#
#   Revision History:
#   =================
#   V1.0    11.11.15 Original By: ACRM
#   V1.1    11.11.15 Added quiz support
#   V1.2    05.01.16 Added [link] and [figure]
#
#*************************************************************************
# Add the path of the executable to the library path
use FindBin;
use Cwd qw(abs_path);

use lib $FindBin::Bin;
# Or if we have a bin directory and a lib directory
#use FindBin;
#use lib abs_path("$FindBin::Bin/../lib");
use genquiz;

#*************************************************************************
use strict;
$::accordionCount = 0;
$::collapseCount  = 0;
%::attribute      = ();

UsageDie()   if(defined($::h));
CleanupDie() if(defined($::clean));

if(scalar(@ARGV))
{
    WriteCSSandJS();            # Write CSS and JavaScript files

    my @data = <>;              # Read the input HTML file

    # The title from the <title> tag
    my $title = GetTitle(@data);
    print "Title: $title\n" if(defined($::debug));

    # Any style information
    my $style = GetStyle(@data);
    print "Style: $style\n" if(defined($::debug));

    # Menu items from [page menu='xxx'] tags
    my $aMenu  = GetMenuItems(@data);
    if(defined($::debug))
    {
        print "Menu: |";
        foreach my $menu (@$aMenu)
        {
            print " $menu |";
        }
        print "\n";
    }
    
    # Taken from the [bigheading] <h1>
    my $homeMenu = GetHomeMenu(@data);
    print "Home menu item: $homeMenu\n" if(defined($::debug));
    
    # Split up the pages and create each one
    my $aPages = GetPages(@data);
    my $pageNum = 0;
    foreach my $aPage (@$aPages)
    {
        my $lastPage = 0;
        $lastPage = 1 if($pageNum == (scalar(@$aPages) - 1));
        WritePage($pageNum, $title, $style, $homeMenu, $aMenu, $aPage, $lastPage);
        $pageNum++;
    }
}
else
{
    UsageDie();
}


#*************************************************************************
#> void WriteCSSandJS(void)
#  ------------------------
#  Writes the supporting CSS and JavaScript files:
#     mptheme.css      - static menu theme support
#     mpcss.css        - special extras for makepages
#     mpautotooltip.js - activate tooltips
#
#  11.11.15 Original   By: ACRM
#
sub WriteCSSandJS
{
    my $share = Cwd::abs_path("$FindBin::Bin/share");
    `cp $share/bootify/throbber.gif .`;
    `cp $share/bootify/mptheme.css .`;
    `cp $share/bootify/mpcss.css .`;
    `cp $share/bootify/mpautotooltip.js .`;
}


#*************************************************************************
#> void UsageDie(void)
#  -------------------
#  Prints a usage message and exits
#
#  11.11.15 Original   By: ACRM
#  05.01.16 V1.2 - corrected program name!
#
sub UsageDie
{
    print <<__EOF;

bootify V1.2 (c) UCL, Dr. Andrew C.R. Martin

Usage: bootify file.html
       -or-
       bootify -clean

Note that every piece of meta-HTML must appear on a single line in the input.

__EOF
    exit 0;
}


#*************************************************************************
#> my $title = GetTitle(@data)
#  ---------------------------
#  Extracts the title from the <title> tag in the HTML
#
#  11.11.15 Original   By: ACRM
#
sub GetTitle
{
    my(@data) = @_;
    my $title = '';
    my $allData = join(' ', @data);
    $allData =~ s/\r//g;
    $allData =~ s/\n/<ret>/g;

    if($allData=~/<title>(.*?)<\/title>/)
    {
        $title = $1;
    }
    $title =~ s/<ret>/ /g;
    return($title);
}


#*************************************************************************
#> my $style = GetStyle(@data)
#  ---------------------------
#  Extracts any <style> information from the HTML. Only reads the 
#  first style tag - does not pick up external style information
#
#  11.11.15 Original   By: ACRM
#
sub GetStyle
{
    my(@data) = @_;
    my $style = '';
    my $allData = join(' ', @data);

    $allData =~ s/\r//g;
    $allData =~ s/\n/<ret>/g;

    if($allData=~/<style.*?>(.*?)<\/style>/)
    {
        $style = $1;
    }
    $style =~ s/<ret>/\n/g;
    return($style);
}


#*************************************************************************
#> $aMenu  = GetMenuItems(@data)
#  -----------------------------
#  Extracts menu items from [page menu='xxx'] metatags. Returns
#  an array reference
#
#  11.11.15 Original   By: ACRM
#
sub GetMenuItems
{
    my(@data) = @_;
    my @menu = ();
    foreach my $line (@data)
    {
        if($line =~ /<!--\s+\[page\s+menu=['"](.*?)['"]\]\s+--\>/)
        {
            push @menu, $1;
        }
    }
    return(\@menu);
}


#*************************************************************************
#> $aPages = GetPages(@data)
#  -------------------------
#  Splits the HTML into separate pages using the [page] metatags.
#  Returns an array reference
#
#  11.11.15 Original   By: ACRM
#
sub GetPages
{
    my(@data) = @_;
    my @Pages = ();
    my $inPage = 0;
    my $pageNum = 0;

    foreach my $line (@data)
    {
        if($inPage)
        {
            push(@{$Pages[$pageNum]}, $line);
        }

        if($line =~ /\<!--\s+\[page\s.*\]\s+--\>/)
        {
            @{$Pages[$pageNum]} = ();
            push(@{$Pages[$pageNum]}, $line);
            $inPage = 1;
        }
        elsif($line =~ /<!--\s+\[\/page\]\s+--\>/)
        {
            $inPage = 0;
            $pageNum++;
        }
    }    
    return(\@Pages);
}


#*************************************************************************
#> void WritePage($pageNum, $title, $style, $homeMenu, $aMenu, 
#                 $aPage, $lastPage)
#  --------------------------------------------------------------
#  $pageNum  - The page number.  0 gives index.html
#                               >0 gives pageN.html
#  $title    - Contents of <title> tag
#  $style    - Any contents of <style> tag
#  $homeMenu - A title-like home menu item taken from the 
#              [bigheading]<h1>
#  $aMenu    - Reference to array of menu items
#  $aPage    - Reference to array of lines for this page
#  $lastPage - Flag to indicate this is the last page so doesn't
#              need a Continue button
#
#  Writes an HTML page
#
#  11.11.15 Original   By: ACRM
#
sub WritePage
{
    my ($pageNum, $title, $style, $homeMenu, $aMenu, $aPage, $lastPage) = @_;

    my $filename = 'index.html';
    if($pageNum)
    {
        $filename = sprintf("page%02d.html", $pageNum);
    }

    if(open(my $fp, '>', $filename))
    {
        PrintHTMLHeader($fp, $title, $style);
        PrintHTMLMenu($fp, $homeMenu, $aMenu, $pageNum);
        PrintHTMLPage($fp, $aPage);
        PrintHTMLNextButton($fp, $pageNum) if(!$lastPage);
        PrintHTMLFooter($fp);
    }

}


#*************************************************************************
#> $homeMenu = GetHomeMenu(@data)
#  ------------------------------
#  Extracts a home menu title from [bigheading]<h1>
#
#  11.11.15 Original   By: ACRM
#
sub GetHomeMenu
{
    my (@data) = @_;
    my $inBigHeading = 0;
    my $inH1 = 0;
    my $h1 = '';
    foreach my $line (@data)
    {
        if($inBigHeading)
        {
            if($line =~ /<h1>/)
            {
                $inH1 = 1;
                $h1 .= $line;
            }
            if($line =~ /<\/h1>/)
            {
                $inH1 = 0;
            }
        }
        if($line =~ /\[bigheading\]/)
        {
            $inBigHeading = 1;
        }
        if($line =~ /\[\/bigheading\]/)
        {
            $inBigHeading = 0;
            last;
        }
    }
    $h1 =~ s/[\n\r]/ /g;
    $h1 =~ /<h1>(.*?)<\/h1>/;
    return($1);
}


#*************************************************************************
#> $line = Replace($line, $tag, $new, [$idStem, $sCounter])
#  --------------------------------------------------------
#  $line     - A line of HTML
#  $tag      - A metatag name to be replaced
#  $new      - The new HTML to relace the metatag
#  $idStem   - An ID to be inserted into the new HTML
#  $sCounter - Reference to a counter to be appended to the ID
#
#  Takes a metatag name and replaces it with the new text. e.g.
#     $line = Replace($line, 'foo', '<div class="bar">');
#     $line = Replace($line, '/foo', '</div>');
#  would replace
#     <!-- [foo] -->
#     <!-- [/foo] -->
#  with
#     <div class="bar">
#     </div>
#
#  Optionally can also build an id from a stem and counter
#  and inserts it into the replacement string. If using this
#  the replacement string must contain '{}' where the id must
#  go. So you could do something like:
#     $count = 0;
#     $line = Replace($line, 'foo', '<div id="{}">', 'bar', \$count);
#  Each call would then replace
#     <!-- [foo] -->
#  with
#     <div id="bar1">
#     <div id="bar2">
#  etc
#
#  11.11.15 Original   By: ACRM
#
sub Replace
{
    my($line, $tag, $new, $idStem, $sCounter) = @_;

    # Construct the regex: <!-- [$tag] -->
    my $regex = '<!--\s+\[' . $tag . '\]\s+--\>';
    if(scalar(@_) > 3)
    {
        if($line =~ /$regex/)
        {
            $$sCounter++;
            my $id = "$idStem$$sCounter";
            $new   =~ s/\{\}/$id/;
            $line  =~ s/$regex/$new/;
        }
    }
    else
    {
        $line =~ s/$regex/$new/;
    }
    return($line);
}


#*************************************************************************
#> $line = ReplaceParam($line, $tag, $attribute, $replace)
#  -------------------------------------------------------
#  $line      - A line of HTML
#  $tag       - The metatag name
#  $attribute - An attribue name
#  $replace   - Replacement text
#
#  Takes a metatag name with an associated attribute and replaces
#  it with the new text inserting the attribute value. e.g.
#     $line = ReplaceParam($line, 'foo', 'bar' '<div class="{}">');
#  would replace
#     <!-- [foo bar='value'] -->
#  with
#     <div class="value">
#
#  11.11.15 Original   By: ACRM
#  05.01.16 {} replacement is now global
#
sub ReplaceParam
{
    my($line, $tag, $attribute, $replace) = @_;
    my $regex = '<!--\s+\[' . $tag . '\s+' . $attribute . "=['\"](.*)['\"]" . '\s*\]\s+--\>';
    if($line =~ $regex)
    {
        my $value = $1;
        $replace =~ s/\{\}/$value/g;
        $line =~ s/$regex/$replace/;
    }
    return($line);
}


#*************************************************************************
#> $line = ReplaceWholeTag($line, $tag, $content)
#  ----------------------------------------------
#  Replaces a whole [tag]...[/tag] with $content
#  If $content contains '{}', then this will be substituted with the
#  text between [tag] and [/tag]
#
#  05.01.16 Original   By: ACRM
#
sub ReplaceWholeTag
{
    my($line, $tag, $newContent) = @_;

    # Construct the regex: <!-- [$tag](.*?)[/$tag] -->
    my $regex = '<!--\s+\[' . $tag . '\]\s+--\>(.*?)<!--\s+\[/' . $tag . '\]\s+--\>';

    if($line =~ /$regex/)
    {
        my $oldContent =  $1;
        $newContent    =~ s/\{\}/$oldContent/g;
        $line          =~ s/$regex/$newContent/;
    }
    return($line);
}


#*************************************************************************
#> $line = ReplaceMultiParams($line, $tag, $aAttributes, $replace)
#  ---------------------------------------------------------------
#  $line        - A line of HTML
#  $tag         - The metatag name
#  $aAttributes - Reference to an array of attribute names
#  $replace     - Replacement text
#
#  Takes a metatag name with an associated set of attributes and replaces
#  it with the new text inserting the attribute values. e.g.
#     $line = ReplaceParam($line, 'foo', \@('bar1','bar2'), '<div class="{0}" style="{1}">');
#  would replace
#     <!-- [foo bar1='value' bar2='border: none'] -->
#  with
#     <div class="value" style="border: none">
#
#  The attribute values are also stored in the global %::attribute{} hash
#
#  05.01.16 Original   By: ACRM
#
sub ReplaceMultiParams
{
    my($line, $tag, $aAttributes, $replace) = @_;
    my $regex = '<!--\s+\[' . $tag . '.*?\]\s+--\>'; # Check if it's this tag
    my $attrCount = 0;
    if($line =~ $regex)
    {
        foreach my $attribute (@$aAttributes)
        {
            my $attrRegex = $attribute . "=['\"](.*?)['\"]";
            if($line =~ /$attrRegex/)
            {
                my $value = $1;
                $replace =~ s/\{$attrCount\}/$value/g;
                $::attribute{$attribute} = $value;
            }
            else
            {
                printf STDERR "Error (bootify): Attribute '$attribute' missing in line -\n";
                printf STDERR "   $line\n";
                exit 1;
            }
            $attrCount++;
        }
        $line =~ s/$regex/$replace/;
    }
    return($line);
}


#*************************************************************************
#> void PrintHTMLFooter($fp)
#  -------------------------
#  Prints the footer for an HTML page
#
#  11.11.15 Original   By: ACRM
#
sub PrintHTMLFooter
{
    my($fp) = @_;

    print $fp <<'__EOF';

    <!-- Bootstrap core JavaScript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->

    <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.1.3/jquery.min.js"></script>
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js" crossorigin="anonymous"></script>
<!--
    <script src="bootstrap/assets/js/jquery.js"></script>
    <script src="bootstrap/dist/js/bootstrap.min.js"></script>
-->
    <script src="mpautotooltip.js"></script>
  </body>
</html>
__EOF
}


#*************************************************************************
#> void PrintHTMLNextButton($fp, $pageNum)
#  ---------------------------------------
#  $fp      - File handle
#  $pageNum - The current page number
#
#  Creates an HTML 'Continue' button providing a link to the next
#  page.
#
#  11.11.15 Original   By: ACRM
#
sub PrintHTMLNextButton
{
    my($fp, $pageNum) = @_;
    my $filename = sprintf("page%02d.html", $pageNum+1);
    print $fp <<__EOF;
<div class='center'>
   <a class="btn btn-lg btn-primary" href="$filename">Continue</a>
</div>
__EOF
}


#*************************************************************************
#> void PrintHTMLMenu($fp, $homeMenu, $aMenu, $pageNum)
#  ----------------------------------------------------
#  $fp       - File handle
#  $homeMenu - The 'home menu' item
#  $aMenu    - Reference to an array of menu items
#  $pageNum  - The current page number (to highlight the current
#              menu item)
#
#  Prints the HTML menu. This is a list formatted with Bootstrap
#
#  11.11.15 Original   By: ACRM
#
sub PrintHTMLMenu
{
    my($fp, $homeMenu, $aMenu, $pageNum) = @_;

    print $fp <<__EOF;
    <!-- Fixed navbar -->
    <div class="navbar navbar-inverse navbar-fixed-top">

      <div class="container">

        <div class="navbar-header">
          <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="index.html">$homeMenu</a>
        </div>

        <div class="navbar-collapse collapse">
          <ul class="nav navbar-nav">
__EOF

    for(my $i=0; $i<scalar(@$aMenu); $i++)
    {
        my $filename = 'index.html';
        my $active   = '';
        $active = " class='active'" if($i == $pageNum);
        if($i)
        {
            $filename = sprintf("page%02d.html", $i);
        }
        print $fp "<li$active><a href='$filename'>$$aMenu[$i]</a></li>\n";
    }

    print $fp <<__EOF;
          </ul>
        </div><!--/.nav-collapse -->
      </div>
    </div>
__EOF
}


#*************************************************************************
#> void PrintHTMLHeader($fp, $title, $style)
#  -----------------------------------------
#  $fp      - File handle
#  $title   - The <title> tag content
#  $style   - Optional style information
#
#  Creates an HTML header for a page
#
#  11.11.15 Original   By: ACRM
#
sub PrintHTMLHeader
{
    my($fp, $title, $style) = @_;

    if($style ne '')
    {
        $style = "<style type='text/css'>$style</style>\n";
    }

    print $fp <<__EOF;
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="">
    <meta name="author" content="">
    <link rel="shortcut icon" href="favicon.png">

    <!-- Bootstrap core CSS -->
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css" crossorigin="anonymous">

    <!-- Bootstrap theme -->
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css" crossorigin="anonymous">

<!-- 
    <link href="bootstrap/dist/css/bootstrap.css" rel="stylesheet">
    <link href="bootstrap/dist/css/bootstrap-theme.min.css" rel="stylesheet">
-->

    <!-- Custom styles for this template -->
    <link href="mptheme.css" rel="stylesheet">

    <!-- And my own useful extras -->
    <link href="mpcss.css" rel="stylesheet"> 

    <!-- Any style information from the web page -->
    $style

    <!-- HTML5 shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->

    <title>$title</title>
  </head>

  <body>
__EOF
}


#*************************************************************************
#> void PrintHTMLPage($fp, $aPage)
#  -------------------------------
#  $fp     - File hanle
#  $aPage  - Reference to array of lines for the page
#
#  The main routine for printing a page of HTML. Calls the various
#  Fixup_*() routines to replace metatags with the relevant HTML.
#  Then prints the lines of HTML to the file
#
#  11.11.15 Original   By: ACRM
#  05.01.16 Added Fixup_link() and Fixup_figure()
#
sub PrintHTMLPage
{
    my($fp, $aPage) = @_;

    print $fp " <div class='container theme-showcase'>\n";

    Fixup_quiz($aPage);
    Fixup_bigheading($aPage);
    Fixup_callout($aPage);
    Fixup_warning($aPage);
    Fixup_important($aPage);
    Fixup_note($aPage);
    Fixup_information($aPage);
    Fixup_popup($aPage);
    Fixup_help($aPage);
    Fixup_instruction($aPage);
    Fixup_accordion($aPage);
    Fixup_ai($aPage);
    Fixup_box($aPage);
    Fixup_confirm($aPage);
    Fixup_link($aPage);
    Fixup_figure($aPage);

    foreach my $line (@$aPage)
    {
        print $fp $line;
    }

    print $fp " </div> <!-- /container -->\n";
}


#*************************************************************************
#> void Fixup_bigheading($aPage)
#  -----------------------------
#  Replaces the [bigheading] metatag with a Bootstrap jumbotron
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_bigheading
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = Replace($line, 'bigheading','<div class="jumbotron">');
        $line = Replace($line, '/bigheading','</div> <!-- jumbotron -->');
    }
}


#*************************************************************************
#> void Fixup_callout($aPage)
#  --------------------------
#  Replaces the [callout] metatag with a Bootstrap info callout
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_callout
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = Replace($line, 'callout','<div class="bs-callout bs-callout-info">');
        $line = Replace($line, '/callout','</div> <!-- callout -->');
    }
}


#*************************************************************************
#> void Fixup_warning($aPage)
#  --------------------------
#  Replaces the [warning] metatag with a Bootstrap danger alert
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_warning
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = Replace($line, 'warning','<div class="alert alert-danger">');
        $line = Replace($line, '/warning','</div> <!-- alert-danger -->');
    }
}


#*************************************************************************
#> void Fixup_important($aPage)
#  ----------------------------
#  Replaces the [important] metatag with a Bootstrap danger callout
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_important
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = Replace($line, 'important','<div class="bs-callout bs-callout-danger">');
        $line = Replace($line, '/important','</div> <!-- bs-callout-danger -->');
    }
}


#*************************************************************************
#> void Fixup_note($aPage)
#  -----------------------
#  Replaces the [note] metatag with a Bootstrap warning callout
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_note
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = Replace($line, 'note','<div class="bs-callout bs-callout-warning">');
        $line = Replace($line, '/note','</div> <!-- bs-callout-warning -->');
    }
}


#*************************************************************************
#> void Fixup_information($aPage)
#  ------------------------------
#  Replaces the [information] metatag with  a Bootstrap info alert
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_information
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = Replace($line, 'information','<div class="alert alert-info">');
        $line = Replace($line, '/information','</div> <!-- alert-info -->');
    }
}


#*************************************************************************
#> void Fixup_instruction($aPage)
#  ------------------------------
#  Replaces the [instruction] metatag with our own instruction class
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_instruction
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = Replace($line, 'instruction','<div class="instruction">');
        $line = Replace($line, '/instruction','</div> <!-- instruction -->');
    }
}


#*************************************************************************
#> void Fixup_popup($aPage)
#  ------------------------
#  Replaces the [popup] metatag with a Bootstrap popup
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_popup
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = ReplaceParam($line, 'popup', 'text', '<a data-toggle="popover" data-trigger="focus" data-content="{}">');
        $line = Replace($line, '/popup','</a>');
    }

}


#*************************************************************************
#> void Fixup_help($aPage)
#  -----------------------
#  Replaces the [help] metatag with a Bootstrap popup and a question mark
#  glyph
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_help
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = ReplaceParam($line, 'help', 'text', '<a data-toggle="popover" data-trigger="focus" data-content="{}">');
        $line = Replace($line, '/help','<span class="glyphicon glyphicon-question-sign"></span></a>');
    }

}


#*************************************************************************
#> void Fixup_accordion($aPage)
#  ----------------------------
#  Replaces the [accordion] metatag with a Bootstrap accordion panel group
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_accordion
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = Replace($line, 'accordion', '<div class="panel-group" id="{}">', 'accordion', \$::accordionCount);
        $line = Replace($line, '/accordion','</div> <!-- panel-group -->');
    }

}


#*************************************************************************
#> void Fixup_ai($aPage)
#  ---------------------
#  Replaces the [ai title='xxx'] metatag with an accordion item
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_ai
{
    my($aPage) = @_;

    my $regexStart = '<!--\s+\[ai\s+title=[\'\"](.*)[\'\"]\s*\]\s+--\>';
    my $regexStop  = '<!--\s+\[\/ai\]\s+--\>';
    my $accordion  = "accordion$::accordionCount";

    foreach my $line (@$aPage)
    {
        if($line =~ /$regexStart/)
        {
            my $title = $1;
            $::collapseCount++;
            my $collapse = "collapse$::collapseCount";
            $line = "  <div class='panel panel-default'>
    <div class='panel-heading'>
      <h4 class='panel-title'>
        <a class='accordion-toggle' data-toggle='collapse' data-parent='#$accordion' href='#$collapse'>
           <span class='glyphicon glyphicon-collapse-down'></span> $title
        </a>
      </h4>
    </div>
    <div id='$collapse' class='panel-collapse collapse'>
      <div class='panel-body'>";
        }
        elsif($line =~ /$regexStop/)
        {
            $line = "      </div>\n    </div>\n  </div>\n";
        }
    }
}


#*************************************************************************
#> void Fixup_box($aPage)
#  ----------------------
#  Replaces the [box title='xxx'] metatag with a Bootstrap panel
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_box
{
    my($aPage) = @_;

    my $replace = "<div  class='panel panel-default'>
   <div class='panel-heading'>
      <h4 class='panel-title'>{}</h4>
   </div>
   <div class='panel-body'>";


    foreach my $line (@$aPage)
    {
        $line = ReplaceParam($line, 'box', 'title', $replace);
        $line = Replace($line, '/box',"   </div>\n</div>");
    }
}


#*************************************************************************
#> WriteAjaxAndCGI(void)
#  ---------------------
#  Writes the Ajax and CGI script to support the confirm box as well
#  as the .htacess file to enable the CGI script
#
#  11.11.15 Original   By: ACRM
#
sub WriteAjaxAndCGI
{
    my $share = Cwd::abs_path("$FindBin::Bin/share");
    `cp $share/bootify/mpajax.js .`;
    `cp $share/bootify/mpparticipation.cgi .`;
    `cp $share/bootify/htaccess ./.htaccess`;
}


#*************************************************************************
#> void MakeResponseDirectory(void)
#  --------------------------------
#  Creates a directory for the participants' responses
#
#  11.11.15 Original   By: ACRM
#
sub MakeResponseDirectory
{
    my $dir = 'participants';
    if(! -d $dir)
    {
        `mkdir $dir`;
        `chmod a+w $dir`;
        `chmod a+t $dir`;
        `chmod u+s $dir`;
    }
}


#*************************************************************************
#> void Fixup_confirm($aPage)
#  --------------------------
#  Replaces the [confirm] metatag with our AJAX/CGI for confirming
#  participation
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_confirm
{
    my($aPage) = @_;

    my $regexStart = '<!--\s+\[confirm]\s+--\>';
    my $regexStop  = '<!--\s+\[\/confirm\]\s+--\>';

    foreach my $line (@$aPage)
    {
        if($line =~ /$regexStart/)
        {
            WriteAjaxAndCGI();
            MakeResponseDirectory();
            $line = "
<script src='mpajax.js'></script>
<div class='bs-callout bs-callout-warning'> 
   <div id='nameentry'>
      <h4>
";
        }
        elsif($line =~ /$regexStop/)
        {
            $line = "
      </h4>
      <form>
         <table>
            <tr><th>Name:</th><td><input type='text' size='40' name='name' id='name' /></td</tr>
            <tr><th>Email:</th><td><input type='text' size='40' name='email' id='email' /></td></tr>
         </table>
         <p><input type='checkbox' name='confirmed' id='confirmed' /> I confirm the above statement.</p>
         <p>&nbsp;</p>
         <p><input type='button' value='Submit' onclick='DisplayPage()' />
            <span id='throbber' style='display:none'><img src='throbber.gif' alt='throbber'/>Saving details...</span>
         </p>
      </form>
      <p>&nbsp;</p>
   </div>
   <div id='response' style='display:none'>&nbsp;</div>
</div>
";
        }
    }
}


#*************************************************************************
#> void CleanupDie(void)
#  ---------------------
#  Remove files generated by the script
#
#  11.11.15 Original   By: ACRM
#
sub CleanupDie
{
    `\\rm -f mpajax.js`;
    `\\rm -f mpcss.css`;
    `\\rm -f mptheme.css`;
    `\\rm -f mpautotooltip.js`;
    `\\rm -f mpparticipation.cgi`;
    `\\rm -i index.html .htaccess page*.html throbber.gif`;

    exit(0);
}


#*************************************************************************
#> void Fixup_quiz($aPage)
#  ----------------------
#  Replaces the [box title='xxx'] metatag with a Bootstrap panel
#
#  11.11.15 Original   By: ACRM
#
sub Fixup_quiz
{
    my($aPage) = @_;
    my $hasQuiz = 0;
    my $startTag = '<!--\s+\[quiz\]\s+--\>';
    my $endTag   = '<!--\s+\[/quiz\]\s+--\>';

    # First see if there is a quiz on this page
    foreach my $line (@$aPage)
    {
        if($line =~ /$startTag/)
        {
            $hasQuiz = 1;
            last;
        }
    }

    # If there is a quiz...
    if($hasQuiz)
    {
        my $giveAnswer = 0;

        # copy the lines leading up to the quiz
        my @outPage = ();
        foreach my $line (@$aPage)
        {
            last if($line =~ /$startTag/);
            push @outPage, $line;
        }

        # copy the quiz itself
        my @quiz = ();
        my $inQuiz = 0;
        foreach my $line (@$aPage)
        {
            last if($line =~ /$endTag/);
            push @quiz, $line if($inQuiz);
            $inQuiz = 1 if($line =~ /$startTag/);
        }

        # process the quiz
        genquiz::ParseQuiz(@quiz);
        my $html = genquiz::WriteJavaScript($giveAnswer, 
                                            $::css, 
                                            \@::correct, 
                                            \@::explanations, 
                                            \@::notes);
        $html .= genquiz::WriteQuiz($::title, $::subtitle);

        # Add this to our output
        push @outPage, $html;

        # Add the rest of the input page
        my $inSection = 0;
        foreach my $line (@$aPage)
        {
            push @outPage, $line if($inSection);
            $inSection = 1 if($line =~ /$endTag/);
        }

        # Finally copy the output array 
        @$aPage = ();
        foreach my $line (@outPage)
        {
            push @$aPage, $line;
        }
    }
}

#*************************************************************************
#> void Fixup_link($aPage)
#  -----------------------
#  Replaces the [link] metatag with a <a href='xxx'>xxx</a>
#
#  05.01.16 Original   By: ACRM
#
sub Fixup_link
{
    my($aPage) = @_;

    foreach my $line (@$aPage)
    {
        $line = ReplaceWholeTag($line, 'link',"<a href='{}' target='links'>{}</a>");
    }
}

#*************************************************************************
#> void Fixup_link($aPage)
#  -----------------------
#  Replaces the [link] metatag with a <a href='xxx'>xxx</a>
#
#  05.01.16 Original   By: ACRM
#
sub Fixup_figure
{
    my($aPage) = @_;
    my @attributes = ('src', 'float', 'number', 'position');

    foreach my $line (@$aPage)
    {
        my $replacement  = "
   <div style='float:{1}; width:350px; margin:0px 10px; border: 1pt solid #666666; padding:5px;'>
   <img src='{0}' width='100%' alt='{0}' />
   <a tabindex='0' data-placement='{3}' role='button' data-toggle='popover' data-trigger='focus' title='Figure {2}' data-content=\"";
        $line = ReplaceMultiParams($line, 'figure', \@attributes, $replacement);
        $line = Replace($line, '/figure', "\">Figure $::attribute{'number'}<span class='glyphicon glyphicon-new-window'></span></a>\n</div>");
    }
}
