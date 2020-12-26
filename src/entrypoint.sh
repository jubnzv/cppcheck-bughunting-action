#!/bin/bash
set -eux
set -o pipefail


# This is populated by our secret from the Workflow file.
if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Set the GITHUB_TOKEN env variable."
	exit 1
fi

echo "current commit"
git log -1

echo "git status"
git status

echo "git diff"
git diff

echo "event payload:"
cat $GITHUB_EVENT_PATH

find_base_commit() {
    BASE_COMMIT=$(
        jq \
            --raw-output \
            .pull_request.base.sha \
            "$GITHUB_EVENT_PATH"
    )
    # If this is not a pull request action it can be a check suite re-requested
    if [ "$BASE_COMMIT" == null ]; then
        BASE_COMMIT=$(
            jq \
                --raw-output \
                .check_suite.pull_requests[0].base.sha \
                "$GITHUB_EVENT_PATH"
        )
    fi
    echo "BASE_COMMIT: $BASE_COMMIT"
}

find_head_commit() {
    HEAD_COMMIT=$(
        jq \
            --raw-output \
            .pull_request.head.sha \
            "$GITHUB_EVENT_PATH"
    )
    echo "HEAD_COMMIT: $HEAD_COMMIT"
}

ACTION=$(
    jq --raw-output .action "$GITHUB_EVENT_PATH"
)
# First 2 actions are for pull requests, last 2 are for check suites.
ENABLED_ACTIONS='synchronize opened requested rerequested'


main() {
    if [[ $ENABLED_ACTIONS != *"$ACTION"* ]]; then
        echo -e "Not interested in this event: $ACTION.\nExiting..."
        exit
    fi

    find_base_commit
    find_head_commit
    # Get files Added or Modified wrt base commit, filter for Python,
    # replace new lines with space.

    # currently in github actions the base commit is the original commit the PR was branched from
    # we could try to rebase on top of the HEAD of dev to make sure it picks up the new code in dev
    new_files_in_branch=$(
        git diff \
            --name-only \
            --diff-filter=AM \
            "$BASE_COMMIT"
    )
    new_files_in_branch1=$(echo $new_files_in_branch | tr '\n' ' ')

    echo "New files in PR: $new_files_in_branch1"
    if [[ $new_files_in_branch =~ .*".py".* ]]; then
        new_c_cpp_files_in_branch=$(
            git diff \
                --name-only \
                --diff-filter=AM \
                "$BASE_COMMIT" | egrep '\.c(c|pp)?$' | tr '\n' ' '
        )
        echo "New C/C++ files in PR: $new_c_cpp_files_in_branch"
        cppcheck --xml --bug-hunting $new_c_cpp_files_in_branch 2> cppcheck_output.xml || true # NOQA
    else
        echo "No new C/C++ files in PR"
    fi
    cppcheck --xml --bug-hunting $new_files_in_branch 2> cppcheck_output.xml || true # NOQA
    python /src/main.py
}

main "$@"
