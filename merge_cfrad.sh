#!/bin/bash

#This file requires netcdf and lrose to be installed

get_el() {
	local file="$1"
	echo "Current file and fixed angle:"
	echo $file
	ncdump $file | grep "fixed_angle = "
}

output_dir=""
use_output_dir=false

# Manual argument parsing
args=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		-o)
			if [[ -n "$2" ]]; then
				output_dir=$(realpath "$2")
				use_output_dir=true
				shift 2
			else
				echo "Option -o requires an argument."
				exit 1
			fi
			;;
		-*)
			echo "Unknown option: $1"
			exit 1
			;;
		*)
			args+=("$1")
			shift
			;;
	esac
done

# Restore positional parameters
set -- "${args[@]}"

if [ -z "$1" ]; then
	echo "Usage: $0 <filename>"
	exit 1
fi

old_dir=$(pwd)

if $use_output_dir; then
	mkdir -p "$output_dir" || { echo "Failed to create output directory"; exit 1; }
	output_path="$output_dir"
else
	output_path="$old_dir"
fi

echo "Outputting to $output_path"

file_path=$(realpath "$1")
file_dir=$(dirname "$file_path")
file_name=$(basename "$file_path")

cd $file_dir

files=(*)
current_index=0

for i in "${!files[@]}"; do
	if [[ "${files[$i]}" == "$file_name" ]]; then
		current_index=$i
		break
	fi
done

while true; do
	# Process the current file
	echo
	get_el "${files[$current_index]}"
	
	# Prompt user for direction
	echo "Enter 'f' to move forward, 'b' to move backward, 'a' to start adding files, or 'q' to quit:"
	read -r direction
	
	case $direction in
		f)
			((current_index++))
			if ((current_index >= ${#files[@]})); then
				echo "This is the last file in the folder, did not move."
				((current_index--))
			fi
			;;
		b)
			((current_index--))
			if ((current_index < 0)); then
				echo "This is the first file in the folder, did not move."
				((current_index++))
			fi
			;;
		a)
			while true; do
				selected_files+=("${files[$current_index]}")
				echo "Added ${files[$current_index]} to the list."
				
				# Move forward
				((current_index++))
				if ((current_index >= ${#files[@]})); then
					echo "No more files to add."
					break
				fi
				
				# Ask if the user wants to continue adding files
				echo
				echo "Next file is:"
				get_el "${files[$current_index]}"
				echo "Add this file? (y/n):"
				read -r add_more
				if [[ "$add_more" != "y" ]]; then
					break
				fi
			done
			break
			;;
		q)
			echo "Exiting."
			exit 0
			;;
		*)
			echo "Invalid input. Please enter 'f', 'b', or 'q'."
			;;
	esac
done

echo
echo "Selected files:"
for file in "${selected_files[@]}"; do
	echo "$file"
done

echo "Do you want to merge the selected files? (y/n):"
read -r response

if [[ "$response" != "y" ]]; then
	echo "Exiting without merging."
	exit 0
fi

echo "Merging selected files..."

file_glob="${selected_files[*]}"
RadxConvert -ag_all -f $file_glob -outdir $output_path
