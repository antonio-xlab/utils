#!/bin/bash

#
# Script which deletes all but the latest N images from each repository under an Azure Container Registry.
# Supports dry-runs (i.e no actual deletions of Azure resources is done).
#
# USAGE
# Format: sh az_cr_cleanup_script.sh <ARG_DRY_RUN> <ARG_CONTAINER_REGISTRY_NAME> <ARG_KEEP_N_LATEST> <ARG_REPO_NAMES_OPTIONAL>
# Examples: sh az_cr_cleanup_script.sh 1 moonstonedevacr 3
#			sh az_cr_cleanup_script.sh 1 moonstonedevacr 3 borderforce,borderforce_webapp,borderforce_worker
#			sh az_cr_cleanup_script.sh 0 moonstonedevacr 3
#			sh az_cr_cleanup_script.sh 0 moonstonedevacr 3 labgnostic-processor,labgnostic-lab2lab
#

DEFAULTIFS=$IFS

# INPUTS
dry_run=$1 				# 1 = dry run (doesn't delete any resources) | 0 = actual run (deletes Azure resources)
registry_name=$2 		# e.g moonstonedevacr
keep=$3 				# keep N latest images in a given repository
repository_names=$4 	# comma separated list of repositories (by name) to run cleanup script in

# OUTPUTS
deleted=0 # how many images have been purged by the end of the script

# ARG VALIDATION
if [[ $# -lt 3 ]] || [[ $# -gt 4 ]]; then
	echo "Example usage:"
	echo "	sh az_cr_cleanup_script.sh 1 moonstonedevacr 3 (for a dry-run)"
	echo "	sh az_cr_cleanup_script.sh 0 moonstonedevacr 3 labgnostic-processor,labgnostic-lab2lab (for a dry run on specified repositories)"
	echo "	sh az_cr_cleanup_script.sh 0 moonstonedevacr 3 (for an actual run)"
	exit 1
fi

if [ "$dry_run" -eq 1 ]; then
	echo "Note that this is a dry-run and that no image tags will be deleted."
else
	echo "Note that this is not a dry-run and that image tags *will* be deleted."
fi

# Figure out whether to cleanup all repositories under the registry or only given ones
if [ "$repository_names" == "" ] || [ "$repository_names" == " " ] || [ "$repository_names" == "\n" ]; then

	# NO REPOSITORY NAMES PROVIDED, run in all repositories found under the given registry

	echo "Querying the entire $registry_name registry."
	repositories=$(az acr repository list --name $registry_name --output json | jq -r '.[]')

	for repo in $repositories; do

		tags=$(az acr repository show-tags --name $registry_name --repository $repo --orderby time_desc --output json | jq -r '.[]' | tail -n+$((keep + 1)))
		
		# Skip repositories with no tags
		if [ "$tags" == "" ] || [ "$tags" == " " ] || [ "$tags" == "\n" ]; then
			continue
		fi

		deleted_in_repo=0
		for tag in $tags; do
			if [ "$dry_run" -eq 1 ]; then
				# Log in console as marked for deletion, but don't delete
				echo "Image to delete: $repo:$tag"
			else
				# Actual deletion of tags from the given repo
				az acr repository delete --name $registry_name --image $repo:$tag -y
			fi

			# Track number of deleted images, both globally and in the given repository
			deleted=$((deleted + 1))
			deleted_in_repo=$((deleted_in_repo + 1))
		done

		if [ "$dry_run" -eq 1 ]; then
			echo "Found $deleted_in_repo images that could be cleaned up in $repo."
		else
			echo "Deleted $deleted_in_repo images in $repo."
		fi
	done
else

	# REPOSITORY NAMES PROVIDED, run script only in the those ones

	echo "Querying the given repositories under $registry_name."
	IFS="," read -ra repositories <<< "$repository_names"
	IFS=$DEFAULTIFS

	for repo_element in "${repositories[@]}"; do

		repo="$repo_element"

		tags=$(az acr repository show-tags --name $registry_name --repository $repo --orderby time_desc --output json | jq -r '.[]' | tail -n+$((keep + 1)))
		
		# Skip repositories with no tags
		if [ "$tags" == "" ] || [ "$tags" == " " ] || [ "$tags" == "\n" ]; then
			continue
		fi

		deleted_in_repo=0
		for tag in $tags; do
			if [ "$dry_run" -eq 1 ]; then
				# Log in console as marked for deletion, but don't delete
				echo "Image to delete: $repo:$tag"
			else
				# Actual deletion of tags from the given repo
				az acr repository delete --name $registry_name --image $repo:$tag -y
			fi

			# Track number of deleted images, both globally and in the given repository
			deleted=$((deleted + 1))
			deleted_in_repo=$((deleted_in_repo + 1))
		done

		if [ "$dry_run" -eq 1 ]; then
			echo "Found $deleted_in_repo images that could be cleaned up in $repo."
		else
			echo "Deleted $deleted_in_repo images in $repo."
		fi
	done
fi

if [ "$dry_run" -eq 1 ]; then
	echo "Script dry-run completed. $deleted images processed for deletion. 0 actually deleted."
else
	echo "Script execution completed. $deleted images processed for deletion. $deleted actually deleted."
fi
