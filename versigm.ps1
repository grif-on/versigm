function scriptOptions() {
	
	# Replace tryToGetProjectDirectory with regullar path if script placed not inside project folder
	$global:project_directory = tryToGetProjectDirectory
	
	# Options file to consider having always actual version number
	$global:master_options_path = "$global:project_directory/options/windows/options_windows.yy"
	
	$global:other_options_paths = @(
		"$global:project_directory/options/linux/options_linux.yy",
		"$global:project_directory/options/android/options_android.yy",
		"$global:project_directory/options/mac/options_mac.yy",
		"$global:project_directory/options/ios/options_ios.yy",
		"$global:project_directory/options/tvos/options_tvos.yy",
		"$global:project_directory/options/html5/options_html5.yy"
	)
	
}


#region Helper functions

function tryToGetProjectDirectory() {
	
	return ".." # todo - actually implement , lol
	
}

function getPlatformNameFromOptionsPath($path) {
	
	# e.g. "../options/windows/options_windows.yy" --> "windows"
	return $path.Split("_")[1].Split(".")[0]
	
}


#endregion Helper functions


scriptOptions


#region Main script part

# Note
# ConvertFrom-Json/ConvertTo-Json are simplier to use but they have different json formating comparing to gamemaker

$options = Get-Content -Path $global:master_options_path

# testing
$version_line = $options[31].Split("`"")
$version_line[3] = "yes"
$options[31] = $version_line -join "`""

$options_string = $options -join "`n"

Set-Content -NoNewline -Path $global:master_options_path -Value $options_string

#endregion Main script part