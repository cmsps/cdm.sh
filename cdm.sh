#!/bin/sh
#
# cdm.sh -  `cd' command with menu
#
# Tue May 12 16:57:52 BST 2015
#


<<'______________D__O__C__U__M__E__N__T__A__T__I__O__N_____________'

Copyright (C) 2016 Peter Scott - p.scott@shu.ac.uk

Licence
-------
   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.


Quick start
-----------
   Type:
        $ eval `cdm.sh -f`
        $ ci

   and you will see a menu for your current directory.


User-created files in $HOME/.cdm
--------------------------------
   cdm's configuration files are held in a hidden directory in $HOME.
   If $NAME is cdm, the directory is $HOME/.cdm.  The user-created files
   are called seed and skip; both have one entry per line.

   seed
   ~~~~
      seed contains a list of absolute path names; cdm adds them to
      the top of the menu.  Example .cdm/seed file:

      /etc
      /usr/local/bin


   skip
   ~~~~
      skip contains a list of ignored directory names.  These are
      not pathnames.  Example .cdm/skip file:

      Bin
      SCCS


Other files in $HOME/.cdm
-------------------------
   There are three automatically created files in $HOME/.cdm called:
   menu, dirs and last.

   .cdm/last holds a "cd" command to the last selected directory; it
   can be sourced in .bashrc so that new shells automatically start
   in the last directory chosen.  cdm's -t option prevents .cdm/last
   being written.


User-created overide files
--------------------------
   Files called .cdmList can exist in any directory; they overide how
   the directory is displayed by cdm.

   If a .cdmList file exists in a directory, the file's contents are used
   instead of the directory's contents.  Therefore, an empty .cdmList simply
   hides all the sub-directories.  Otherwise, .cdmList holds a manually
   generated tree of sub-directories.

   .cdmList files have one entry per line.  Three example .cdmList files:

        +-hilary                +-jill                `-harry
        +-dick                  '-jack
        | +-mehdi
        | | `-lisa
        | |   `-doreen
        | `-susan
        `-helena

   (You can use "`-" or "'-" in the drawing.  The simplest way to generate
   a tree is to run the tree command in the directory and edit the
   output.)

   The existence of a .cdmList file in a target directory causes cdm to
   recurse and offer another menu.


Installation
------------
  If you simply run cdm.sh, it displays installation instructions.

  You have to use:

       eval `cdm.sh -f`

  The eval command will install functions called "cdm" and "ci" which
  both call cdm.sh and change directory.  The eval command should be
  added to one of your shell startup files (such as .bashrc) to ensure
  every shell you start gets the cdm and ci functions defined.


Terminals supported
-------------------
  Terminals aren't explicitly supported.  I use cdm on xterms but I
  haven't yet found a terminal type where it doesn't work.  When $DISPLAY
  isn't set, cdm draws the menu tree with these characters: "|+'-".


Main programs used
------------------
   tree:    does most of the tree drawing; it is readily available for Linux.

   awk:     must allow user-defined functions.  cdm uses gawk for Linux and
            nawk otherwise.


Problems
--------
  (1) Directory names starting with '-' must be selected numerically.
      They are hard to read as they merge with line drawing characters.

  (2) Directories whose name are numbers (eg: 2015) have to be chosen by
      menu number.

  (3) Names beginning with other line drawing characters or containing
      slashes will probably mess things up.

  (4) Symbolic links are ignored.  This probably isn't a problem.


______________D__O__C__U__M__E__N__T__A__T__I__O__N_____________

NAME='cdm'
EXT='sh'
PREFIX='CDM_'
ALIAS='ci'   # alias for cdm -i

SEED="$HOME/.$NAME/seed"
SKIP="$HOME/.$NAME/skip"
MENU="$HOME/.$NAME/menu"
DIRS="$HOME/.$NAME/dirs"
LAST="$HOME/.$NAME/last"
LIST=".${NAME}List"

TMP="/tmp/$NAME.$$"

# do not mess up these two constants by trying to paste the file
# instead of downloading it
#
START_LINEMODE='(0'
END_LINEMODE='(B'


# myLs - display the chosen directory (you probably wish to customise this)
#
myLs(){
  echo "`pwd`/"                  # $PWD doesn't work fully in Solaris shell
  echo "`pwd`/" | sed 's/./~/g'
  ls -F
  if [ -d Bin ]
  then printf "\nBin/\n"
       ls Bin
  fi
}


# myTitlebar string - update window's title-bar
#                     (you can delete or customise this)
#
myTitlebar(){
  local string=$1

  echo -ne "\033]0;${string}\007" > /dev/tty     # update xterm title
}


# usage - display usage on standard error
#
usage(){
  cat <<-! >&2
	Usage: $NAME [ -t ]         # select a directory from the menu
	       $NAME [ -t ] choice  # select a directory without seeing a menu
	       $NAME -i [ -h ]      # select from the current directory only
	       $NAME -r [ -ah ]     # rebuild the menu
	       eval \`$NAME.$EXT -f\`   # install the calling function in the shell

	Options:
	       -a   get all directories by ignoring $SKIP
	            and any $LIST files
	       -h   get hidden directories too
	       -i   generate a temporary menu from "."    (implies -a and -t)
	       -r   rebuild default menu
	       -t   do not remember the choice
	       -f   generate the calling function
	!
  exit 1
}


# mkTmp - make temp dir and delete it automatically on exit
#         Eg: mkTmp; ... > $TMP/temp
#
mkTmp(){
  trap 'rm -fr $TMP 2> /dev/null' 0 1 2 3 4 5 6 7 8 9 10    12 13 14 15
  mkdir $TMP && return
  echo " $NAME: couldn't make $TMP directory"  >&2
  exit 2
}


# mkDirs - re-build directory list and menu
#
mkDirs(){

  mkTmp

  # Build argument of dirs for tree command to skip 
  #
  if [ \( "$call2" \) -o \( -z "$all" \) ] && [ -f "$SKIP" ]
  then skip=$(tr '\n' '|' < "$SKIP" |
                sed 's/^/-I /
                     s/.$//')
  fi

  # build tree of all possible directories
  #
  tree $hidden $skip -df --noreport |

  # if not had -a option, build list of edits from user's customisation files
  # otherwise, just build the tree without edits
  #
  if [ "$all" ]
  then # edit tree lines to: remove tree's escapes from spaces
       #                     and condense slightly
       sed 's?\\ ? ?g
            s/|-- /+-/
            s/`-- /`-/
            s/|   /| /g
            s/    /  /g' > $TMP/prunedDirs

  else # edit tree lines to: add a trailing slash (needed for appending)
       #                     remove tree's escapes from spaces
       #                     and condense slightly
       sed 's?$?/?
            s?\\ ? ?g
            s/|-- /+-/
            s/`-- /`-/
            s/|   /| /g
            s/    /  /g' > $TMP/allDirs

       # start building edits; begin by adding delete commands for
       # contents of dirs with a .cdmList file
       #
       find . -name "$LIST" |
         sed 's/^/\\?[+`]-\\/
              s/[^/]*$/.?d/' > $TMP/edits

       # add append commands for dirs with a non-empty .cdmList file
       #
       find . -name "$LIST" -size +1c |
         sed 's?/[^/]*$??' |          # remove ".cdmList"

           # find dir's entry, output its name and display its .cdmList,
           # (allowing for use of "'-" instead of "`-")
           #
           xargs -I {} echo "grep -- '[+\`]-{}/$' $TMP/allDirs; " \
                                                   "tr \"'\" '\`' < {}/$LIST" |
             sh |
               "$AWK" ' \
                 # do the +-./dir/ for the location of the non-empty .cdmList
                 #
                 /^[| ]*[+`]-\./ {
                      if (savedLine)        
                           print( savedLine)
                      savedLine = sprintf( "\\?%s$?a", $0)
                      path = $0
                      sub( /.*\.\//, "./", path)
                      indent1 = $0
                      i2PrevLen = 2

                      # if not last in parent dir
                      #
                      if ($0 ~ /+-\.\//)
                           sub( /+-\.\/.*/, "| ", indent1)
                      else
                           sub( /`-\.\/.*/, "  ", indent1)
                 }
                 # do the lines in the .cdmList file
                 #
                 !/^[| ]*[+`]-\./ {
                      print( savedLine "\\")
                      dirStart = match($0, "-") + 1
                      indent2 = substr($0, 1, dirStart -1)
                      i2Len = length( indent2)
                      if (i2Len > i2PrevLen) {       # assuming by 2!
                           path = path prevDir "/"
                      } else if (i2Len < i2PrevLen) {
                           drops = (i2PrevLen - i2Len) / 2
                           for (n = 0; n < drops; n++)
                                sub( /[^/]+\/$/, "", path)
                      }
                      dir = substr($0, dirStart)
                      savedLine = sprintf( "%s", indent1 indent2 path dir)
                      prevDir = dir
                      i2PrevLen = i2Len
                 }
                 END {
                      if (savedLine)        
                           print( savedLine)
                 }
               ' >> $TMP/edits

       # add command to remove the trailing slash added above
       #
       echo 's?/$??' >> $TMP/edits

       # apply edit(s)
       #
       sed -f $TMP/edits $TMP/allDirs > $TMP/prunedDirs
  fi

  # put seeded dirs at top of dir list and menu
  #
  > "$dirList"
  > "$menu"
  if [ -z "$immediate" ] && [ -f "$SEED" ]
  then cat "$SEED" >> "$dirList"
       cat "$SEED" >> "$menu"
  fi

  # remove tree structure from dir list
  #
  sed 's?^[| +`-][| +`-]*??' $TMP/prunedDirs >> "$dirList"

  # set label for root of tree
  #
  if [ "$immediate" ]
  then root=dot
  else root=home
  fi

  # remove full pathnames from menu, label tree root
  # and convert tree commands's "`-" back to "'-" (looks better)
  #
  sed '\?^\.$?s??('$root')?
       \?/.*/?s?/.*/?/?
       \?-\.\/?s??-?
       \?`-?s??'"'"'-?' $TMP/prunedDirs >> "$menu"
}


# doMenu - show menu (if needed) and get reply
#
doMenu(){
  if [ "$cmdLineChoice" ]
  then reply=$cmdLineChoice
  else test "$COLUMNS" || COLUMNS=80
       entries=`wc -l < "$menu"`
       digits=`printf $entries | wc -c`

       # format menu with line numbers in up to three columns
       # (This is aimed at a 24 line window.)
       #
       if [ $entries -le 22 ]
       then pr -t -n' '$digits -i' '1 "$menu"
       elif [ $entries -le 44 ]
       then lines=`expr \( $entries / 2 \) + \( $entries % 2 \)`
            pr -2 -t -l $lines -n' '$digits -w $COLUMNS -i' '1 "$menu"
       else lines=`expr \( $entries / 3 \) + \( $entries % 3 + 1 \) / 2`
            pr -3 -t -l $lines -n' '$digits -w $COLUMNS -i' '1 "$menu"
       fi |

         # use line-drawing if using an xterm equivalent
         #
         if [ -z "$DISPLAY" ]
         then
              cat
         else
              sed -e "/|/s//${START_LINEMODE}x${END_LINEMODE}/g" \
                  -e "/+-/s//${START_LINEMODE}tq${END_LINEMODE}/g" \
                  -e "/'-/s//${START_LINEMODE}mq${END_LINEMODE}/g"
         fi

       printf '\nWhich? '
       read reply || exit 3
       test "$reply" || exit 4

       # accept    '-t ' option at start of reply
       #
       case "$reply" in
         -t' '* )
            reply=`echo $reply | sed 's/-t  *//'`
            saveCd=
       esac

  fi
}


# showFunction - show function definitions for eval by shell startup script
#
showFunction(){
  printf 'function %s() { %s -i $*; };\n' $ALIAS $NAME
  printf 'function %s() { %s=`%s %s $*` && cd "$%s"; }\n' \
                               $NAME ${PREFIX}DIR $NAME.$EXT $NAME ${PREFIX}DIR
  exit 0
}


# instruct - tell user how to install it
#
instruct(){
  cat <<-! >&2
	$NAME.$EXT shouldn't be run directly as doing so doesn't allow it to
	change directory.  Use:

	     eval \`$NAME.$EXT -f\`

	That will install a function called $NAME which calls $NAME.$EXT and
	changes directory.  The eval statement should be added to one of your
	shell startup files to ensure every shell you start gets the $NAME
	function defined.

	!
    exit 5
}


# badOpt option - report bad option
#
badOpt(){
  option=$1
  case $option in
    f) echo "$NAME: -f must be used with eval" >&2 ;;
    *) echo "$NAME: bad option -- $option" >&2 ;;
 esac
 usage
}


# vetOptions - check mutually exclusive options and set up implied options
#
vetOptions(){
  if [ "$immediate" ] && [ "$build" ]
  then echo "$NAME: warning: ignoring -r with -i" >&2
  fi
  if [ "$immediate" ] && [ "$all" ]
  then echo "$NAME: warning: -i implies -a" >&2
       all=
  fi
  if [ "$all" ] && [ -z "$build" ]
  then echo "$NAME: warning: ignoring -a without -r" >&2
  fi
  if [ "$hidden" ] && [ -z "$build" ] && [ -z "$immediate" ]
  then echo "$NAME: warning: ignoring -h without -i or -r" >&2
  fi
  if [ "$immediate" ]
  then saveCd=         # -i implies: -t
       build=          # -i implies: no -r
       all=true        # -i implies: -a
       menu=$TMP/menu
       dirList=$TMP/dirList
  fi
}


# prevent the user giving the script a name with white space in it
# -- saving the hassle of quoting internal file names
#
words=`echo "$NAME" | wc -w`
if [ $words -ne 1 ]
then echo "\`$NAME': I don't allow white space in command names" >&2
     exit 6
fi

# set up awk program to use
#
case $OSTYPE in
  linux-gnu) AWK=gawk ;;
  *)         AWK=nawk ;;
esac

# show installation function if '-f' is the only parameter
#
if [ "$1" = -f ]
then if [ $# -eq 1 ]
     then showFunction    # exits
     else usage
     fi
fi

# disallow any other direct runs by looking for useless first parameter
#
test "$1" = $NAME || instruct           # exits
shift

# set defaults
#
menu="$MENU"
dirList="$DIRS"
saveCd=true

# handle remaining options
#
while getopts ':ahirt2' option
do   case $option in
       a) all=true ;;
       h) hidden='-a' ;;      # option to tree command
       i) immediate=true ;;
       r) build=true ;;
       t) saveCd= ;;
       2) call2=true ;;       # -2 is for internal use, but is harmless
      \?) badOpt "$OPTARG" ;;
     esac
done
shift `expr $OPTIND - 1`
cmdLineChoice="$*"
vetOptions

# cause menu to be built menu if first run
#
test -d "$HOME/.$NAME" || mkdir "$HOME/.$NAME"
if [ ! -f "$menu" ] && [ -z "$immediate" ] && [ -z "$build" ]
then echo "$NAME: $menu: not found, building it ..." >&2
     build=true
fi

#  build menu if needed (in $HOME if not '-i')
#
if [ "$immediate" ] || [ "$build" ]
then test "$build" && cd
     mkDirs
fi

# use "> /dev/tty" here because cdm.sh is run via command substitution
#
doMenu > /dev/tty

# handle reply
#
case "$reply" in
  0)
     echo "$NAME: $reply: too small" >&2
     exit 7
     ;;
  '(home)' | '(dot)')
     choice=.
     ;;
  *[!0-9]*)
     case $reply in
       /*) slash='' ;;
       *)  slash='/' ;;
     esac
     matches=`grep -c "$slash$reply"'$' "$dirList"`
     case $matches in
       1) choice=`grep "$slash$reply"'$' "$dirList"`
          ;;
       0) echo "$NAME: $reply: not found" >&2
          exit 8
          ;;
       *) echo "$NAME: $reply: ambiguous" >&2
          exit 9
     esac
     ;;
  *)
     entries=`wc -l < "$dirList"`
     if [ "$reply" -le $entries ]
     then choice=`sed -n -e ${reply}p "$dirList"`
     else echo "$NAME: $reply: too big" >&2
          exit 10
     fi
esac

# stick $HOME/ before choice if needed
#
case "$choice" in
  /*)
     : ;;
  *)
     choice=`echo "$choice" | sed 's/^\.\///'`
     test "$immediate" || choice="$HOME/$choice"
esac

# cd to choice if it exists
#
if [ ! -d "$choice" ]
then echo "$NAME: $choice: no such directory" >&2
else cd "$choice"

     # if there is a .cdmList file here and we need to offer the sub-dirs
     #
     if [ -f "$LIST" ] && [ -z "$call2" ] && [ -z "$immediate" ]
     then
          # call myTitlebar, if defined, to put interim choice in title-bar
          #
          type myTitlebar &> /dev/null && myTitlebar "$choice"

          # re-call this script to refine choice
          #
          choice2=`$NAME.$EXT $NAME -i2`
          if [ $? -ne 4 ]
          then # ls will have been done by the above call, or there is an
               # error message we don't want to mask
               #
               noLs=true
          fi
          choice="$choice/$choice2"
     fi

     # echo the choice for the cdm function to cd with!
     #
     echo $choice

     test "$saveCd" && echo "cd '$choice'" > "$LAST"

     # list target dir if not already done it for second choice
     #
     if [ -z "$noLs" ]
     then
          # use "> /dev/tty" here because the script is run via
          # command substitution
          #
          myLs > /dev/tty
     fi
fi
