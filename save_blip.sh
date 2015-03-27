#!/bin/bash
##############################################
#
# This program is provided on an 'as-is' basis.
# No support is offered for any defects found 
# in this program.
# No liability is accepted for any damage 
# caused through the use of this program.
#
##############################################

##############################################
#
# To use this shell script program, copy and
# paste this text into a text editor and
# save the file to your hard disk. Be careful
# that the copy and paste does not introduce
# additional line breaks!
# Then make the file executable:
# chmod +x what_ever_you_called_the_file
# 
# Now you should be able to run the program.
# ./what_ever_you_called_the_file
# The program will then tell you the 
# parameters it needs.
#
# The program will create a subdirectory 
# within the directory you save this script
# to hold all the entries generated. 
##############################################


##############################################
# 
#         ******* NOTE ********* 
# This code relies on two programs other than
# the standard Unix command set, such as 
# mkdir, sed, grep, rm.
#
# These two commands are: wkhtmltopdf and wget
# These two commands *must* be installed and
# in a directory listed in your shell PATH 
# variable.
#
# You can check this from a terminal prompt as 
# follows ($ is just the terminal prompt):
# $ wkhtmltopdf -V
# wkhtmltopdf 0.12.2.1 (with patched qt)
# $ wget -V
# GNU Wget 1.15 built on linux-gnu.
#  ... etc
#
# You will need to install version 0.12.2.1 for
# the print out to be faithful to the Blip page
# layout. You can download that version from
# http://wkhtmltopdf.org/downloads.html
# 
# Bear in mind that you have to trust that this
# download is safe!
#
##############################################

function showusage() {
	echo "There are two forms of usage."
	echo "	The first prints all entries in reverse chronological order given an initial entry"
	echo 
	echo "	Usage:"
	echo "	$0 blip_username with_comments with_headers_and_footers url_of_first_blip_to_print"
	echo 
	echo "	Example:"
	echo "	$0 yourusername y n https://www.polaroidblipfoto.com/entry/1234567890 "
	echo 
	echo "	The second prints entries from an initial entry up to, but not including, a final entry in reverse chronological order."
	echo "	No check is made that the last entry is before the first."
	echo 
	echo "	Usage:"
	echo "	$0 blip_username with_comments with_headers_and_footers url_of_first_blip_to_print url_of_final_blip_to_stop_at"
	echo 
	echo "	Example:"
	echo "	$0 yourusername n y https://www.polaroidblipfoto.com/entry/4321 https://www.polaroidblipfoto.com/entry/1234"
}

if [[ $# -lt 4 ]]; then
	showusage
	exit 1
fi

base_url="https://www.polaroidblipfoto.com"
user=$1
comments=$2
headersandfooters=$3
previous_url=$4
final_url=$5
docomments="var x = 0;"
headerfooterjs="var x = 0;"
tmp_file=/tmp/blip$$

if [[ -z ${final_url} ]]; then
	final_url=${base_url}
fi

if [[ ${comments} != "y" && ${comments} != "n" ]]; then
	echo "Comments option must be y or n"
	showusage
	exit 1
fi

if [[ ${comments} == "y" ]]; then
	docomments='load_comments.scrollIntoView(true); load_comments.click();' 
fi

if [[ ${headersandfooters} != "y" && ${headersandfooters} != "n" ]]; then
	echo "Headers and footers option must be y or n"
	showusage
	exit 1
fi

if [[ ${headersandfooters} == "n" ]]; then
	headerfooterjs='var c = document.getElementsByClassName("topbar").item(0) ; var p = c.parentNode; p.removeChild(c); c = document.getElementsByClassName("footer").item(0) ; var p = c.parentNode; p.removeChild(c);'
fi

# Use a 2 second delay between getting entries.
# Note - producing the PDF may take several second though.
delay=2
blip_entries_dir=./blip_entries

if [[ ! -d ${blip_entries_dir} ]]; then
	echo "Making directory ${blip_entries_dir}"
	mkdir -p ${blip_entries_dir}
	if [[ $? != 0 ]]; then
		echo "Failed to make directory ${blip_entries_dir}"
		exit 1
	fi
fi

# Check that wkhtml and wget are installed

echo "Checking wkhtmltopdf and wget are installed..."
if [[ -z $( which wkhtmltopdf ) ]]; then
	echo "The wkhtmltopdf program was not found in any of the directories"
	echo "on your PATH variable ($PATH)."
	echo "Please download and install wkhtmltopdf, or update your PATH"
	echo "variable before re-running this command."
	exit 1
fi

if [[ -z $( which wget ) ]]; then
	echo "The wget program was not found in any of the directories"
	echo "on your PATH variable ($PATH)."
	echo "Please download and install wget, or update your PATH"
	echo "variable before re-running this command."
	exit 1
fi

# Start by printing a front cover

echo "Printing front cover for user ${user}...."
wkhtmltopdf -q ${base_url}/${user} \
	--run-script "console.log(document.readyState);" \
	--run-script "${headerfooterjs}" \
	./${blip_entries_dir}/front_cover.pdf  \
	> /dev/null 2>&1

while [[ $previous_url != $final_url ]];
do
	wget --no-check-certificate -q -O ${tmp_file} $previous_url
	entry_date=$( grep 'JournalGallery","title":"' ${tmp_file} \
		| sed 's/^.*JournalGallery","title":"//' \
		| sed 's/".*$//' | sed 's/ /_/g' )
	echo "Printing entry ${entry_date}...."
	result=""
	while [[ -z $result ]];
	do
		# Note
		# The run-script function does not always work correctly
		# hence the loop.
		result=$( wkhtmltopdf ${previous_url} \
			--run-script "${headerfooterjs}" \
			--run-script "console.log(document.readyState);" \
			--run-script "${docomments}" \
			--no-stop-slow-scripts  \
			--javascript-delay 2000  \
			--debug-javascript  \
			${blip_entries_dir}/${entry_date}.pdf 2>&1 \
			| egrep "interactive|complete" )
		if [[ -z $result ]]; then
			echo "Retrying...."
			sleep 1
		fi
	done
	previous_url=${base_url}$( grep 'title="Previous"' ${tmp_file} \
		| sed 's/^.*href="//' | sed 's/".*$//' )
	rm ${tmp_file}
	sleep ${delay}
done
