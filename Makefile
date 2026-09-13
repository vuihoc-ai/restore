sha:
	@sed -i "" "s/^\`bootstrap.sh\` = .*/\`bootstrap.sh\` = \\\`$$(shasum -a 256 bootstrap.sh | cut -d" " -f1)\\\`/" README.md && grep "bootstrap.sh\` =" README.md
