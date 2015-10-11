#! /bin/bash

rm -Rf "help"

# dynamic variables
projectName="NetDebug"
projectPath='/Users/pfountas/Documents/GitHub/
docsPath="${projectPath}${projectName}/docs";

/Users/pfountas/Documents/Xcode/appledoc/appledoc \
--project-name "${projectName}" \
--project-company "Petros Fountas" \
--company-id "com.gmail.petros.fountas" \
--docset-atom-filename "${projectName}.atom" \
--docset-feed-url "%DOCSETATOMFILENAME" \
--docset-package-url "%DOCSETPACKAGEFILENAME" \
--docset-fallback-url "" \
--output "help" \
--publish-docset \
--logformat xcode \
--keep-undocumented-objects \
--keep-undocumented-members \
--keep-intermediate-files \
--no-repeat-first-par \
--no-warn-invalid-crossref \
--ignore "*.m" \
--ignore "LoadableCategory.h" \
--index-desc "${projectPath}${projectName}/readme.markdown" \
"${projectPath}${projectName}"

