#!/bin/bash
# https://stackoverflow.com/a/44688216

project="$1"  # HeinrichConvidera/wiki-test
if [[ "$project" == "" ]]
then
    project="$(git config --get remote.origin.url)"
    if [[ "${project##*.}" == "git" ]]
    then
        # git@github.com:HeinrichConvidera.wiki.git
        project="${project%.*}.wiki.git"
    else
        # https://github.com/HeinrichConvidera/wiki-test.git
        project="${project}.wiki"
    fi
else
    if [[ "${project%%:*}" != "http" && "${project%%:*}" != "https" && "${project%%@*}" != "git" ]]
    then
        # not:
        #   - http://github.com/HeinrichConvidera/wiki-test.git
        #   - https://github.com/HeinrichConvidera/wiki-test.git
        #   - git@github.com:HeinrichConvidera.wiki.git
        # build git@... link
        # alternative: build http(s)://... link
        project="git@github.com:${project}.wiki.git"
    fi
fi
echo "$project"


# download wiki
tmp_dir="tmp.$$"
git clone "${project}" "${tmp_dir}"
cd "$tmp_dir"

# custom css
cat >user.css <<EOL
.markdown-body .highlight pre,
.markdown-body pre{
  overflow:visible !important;
}
EOL

# convert *.md to *.md.html using the actual github pipeline
docker run --rm -e DOCKER_USER_ID=`id -u` -e DOCKER_GROUP_ID=`id -u` \
    -v "`pwd`:/src" -v "`pwd`:/out" andyneff/github-markdown-preview

# fix hyperlinks, since wkhtmltopdf is stricter than github servers
docker run --rm -v `pwd`:/src -w /src perl \
    perl -p -i -e 's|(<a href=")([^/"#]+?)(#[^"]*)?(">.*?</a>)|\1\L\2\E.md.html\L\3\E\4|g'\
        *.html

# lowercase all filename so that hyperlink match
docker run --rm -v `pwd`:/src -w /src python \
    python -c 'import sys;import os; [os.rename(f, f.lower()) for f in sys.argv[1:]]' \
        *.md.html

# convert html to pdf using QT webkit
docker run -it --rm -e DOCKER_USER_ID=`id -u` -e DOCKER_GROUP_ID=`id -u`\
    -v `pwd`:/work -w /work andyneff/wkhtmltopdf \
    wkhtmltopdf --encoding utf-8 --minimum-font-size 14 \
        --footer-left "[date]" --footer-right "[page] / [topage]" \
        --footer-font-size 10 \
        --user-style-sheet user.css \
        toc \
        *.html document.pdf

cp "document.pdf" "../document.pdf"
cd ..
rm -rf "$tmp_dir"
