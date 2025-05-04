#region Arguments

# Optional arguments to use script in other ways (rather than default interactive version set)
param (
	# note - SetVersion and GetVersion are mutually exclusive (i.e. use only one per script call)
	[string]$SetVersion, # if present it value will be used instead of interactive prompt result
	[switch]$GetVersion, # if present version will not be set , instead the script will just return version
	[switch]$VersionAsString # if present returned version will be converted to string
)

#endregion Arguments


#region Script options

# Tweak them to fit the needs of your project
function applyScriptOptions() {
	
	# If script fails to execute "tryToGetProjectDirectory" function - replace it with string that points to directory with .yyp project file (remember that you can use relative path)
	$global:project_directory = tryToGetProjectDirectory
	
	# Options file to consider having always actual version number
	$global:master_options_path = "$global:project_directory/options/windows/options_windows.yy"
	
	$global:managed_options_paths = @(
		"$global:project_directory/options/linux/options_linux.yy",
		"$global:project_directory/options/android/options_android.yy",
		"$global:project_directory/options/mac/options_mac.yy",
		"$global:project_directory/options/ios/options_ios.yy",
		"$global:project_directory/options/tvos/options_tvos.yy",
		"$global:project_directory/options/html5/options_html5.yy"
	)
	
}

#endregion


#region Classes

class Version {
	
	[int] $major
	[int] $minor
	[int] $patch
	[int] $revision
	Version([string] $version_string) {
		
		$version_splitted = $version_string.Split(".")
		
		try {
			$this.major = [int] $version_splitted[0]
			$this.minor = [int] $version_splitted[1]
			$this.patch = [int] $version_splitted[2]
			$this.revision = [int] $version_splitted[3]
		} catch {
			Write-Error -Message "Failed to convert `"$version_string`" string in to Version object !"
			exit
		}
		
	}
	[string] ToString() {
		
		return "$($this.major).$($this.minor).$($this.patch).$($this.revision)"
		
	}
	
}

#endregion Classes


#region Functions

function tryToGetProjectDirectory() {
	
	$script_directory = $PSScriptRoot
	$one_directory_back = "$script_directory/.."
	
	if (Test-Path -Path "$script_directory/options" -PathType Container) {
		
		return $script_directory
		
	} elseif (Test-Path -Path "$one_directory_back/options" -PathType Container) {
		
		return $one_directory_back
		
	} else {
		
		$message = "Can't determine path of project directory !"
		$recomendation = "If you placed script outside project directory (or too deep) , then you need to explicitly point script to a project directory (with `"`$global:project_directory`" variable) ."
		Write-Error -Message $message -RecommendedAction $recomendation
		exit
		
	}
	
}

function getPlatformNameFromOptionsPath([string] $path) {
	
	# e.g. "../options/windows/options_windows.yy" --> "windows"
	return $path.Split("_")[1].Split(".")[-2]
	
}

function findIndexThatContains([string[]] $where, [string] $what_to_find, [switch] $stop_when_nothing_found) {
	
	$l = $where.Count - 1
	
	while ($l -ge 0) {
		
		if ($where[$l].Contains($what_to_find)) {
			break
		}
		
		$l--
		
	}
	
	if ($l -le -1) {
		
		if ($stop_when_nothing_found) {
			
			Write-Error -Message "Can't find index !"
			exit
			
		} else {
			
			$l = $null
		
		}
		
	}
	
	return $l
	
}

function readHostWithEditableDefault([string] $prompt, [string] $default_value) {
	
	# More about this abominable workaround - https://stackoverflow.com/questions/23619510/
	# This workaround have one major flaw - default value sends in to foreground window that has focus (and not in to console input buffer directly) .
	# I.e. you need to be sure that user have script window selected for default value to work .
	
	$js_code = 'WScript.CreateObject("WScript.Shell").SendKeys(WScript.Arguments(0));'
	
	# cscript.exe is hardcoded to work only with .js files (i.e. no string execution sadly)
	$temp_js_file = [System.IO.Path]::GetTempFileName() + ".js"
	Set-Content -Path $temp_js_file -Value $js_code
	
	# Start asynchronous JScript which will fill Read-Host input with default value (again , this will work as intended only if console window is in focus)
	cscript.exe //nologo //E:JScript $temp_js_file $default_value
	
	$result = Read-Host -Prompt $prompt
	
	Remove-Item $temp_js_file
	
	return $result
	
}

function getVersion([string] $options_path) {
	
	function extractVersion([string] $options_path) {
		
		$platform = getPlatformNameFromOptionsPath -path $options_path
		
		$options = Get-Content -Path $options_path
		
		$version_index = findIndexThatContains -where $options -what_to_find "option_$platform`_version" -stop_when_nothing_found
		
		$version = $options[$version_index].Split("`"")[3]
		
		# Android and linux doesn't have revision field in IDE , and for them version stored in format "major.minor.patch"
		if ($platform -eq "android" -or $platform -eq "linux") {
			
			$version += "." + "0"
			
		}
		# Apple's have revision as sepparated field in IDE , and again for them version stored in format "major.minor.patch" + revision in it's own option
		elseif ($platform -eq "mac" -or $platform -eq "ios" -or $platform -eq "tvos") {
			
			$revision_index = findIndexThatContains -where $options -what_to_find "option_$platform`_build_number" -stop_when_nothing_found
			
			$version += "." + $options[$revision_index].Split("`"")[2].Replace(":", "").Replace(",", "")
			
		}
		
		return $version
		
	}
	
	$version_string = extractVersion -options_path $options_path
		
	return (New-Object -TypeName Version -ArgumentList @($version_string))
	
}

function setVersion([string] $options_path, [Version] $version) {
	
	$platform = getPlatformNameFromOptionsPath -path $options_path
	
	$version_string = $version.ToString()
	$revision_string = ""
	
	# Android and linux doesn't have revision field in IDE , and for them version stored in format "major.minor.patch"
	if ($platform -eq "android" -or $platform -eq "linux") {
			
		$version_string = "$($version.major).$($version.minor).$($version.patch)"
	
	}
	# Apple's have revision as sepparated field in IDE , and again for them version stored in format "major.minor.patch" + revision in it's own option
	elseif ($platform -eq "mac" -or $platform -eq "ios" -or $platform -eq "tvos") {
				
		$version_string = "$($version.major).$($version.minor).$($version.patch)"
		$revision_string = $version.revision
		
	}
	
	function writeVersion([string] $options_path, [string] $version, [string] $revision) {
		
		$platform = getPlatformNameFromOptionsPath -path $options_path
		
		$options = Get-Content -Path $options_path
		
		$version_index = findIndexThatContains -where $options -what_to_find "option_$platform`_version" -stop_when_nothing_found
		
		$version_line = $options[$version_index].Split("`"")
		$version_line[3] = $version
		$options[$version_index] = $version_line -join "`""
		
		if ($revision -ne "") {
			
			$revision_index = findIndexThatContains -where $options -what_to_find "option_$platform`_build_number" -stop_when_nothing_found
			
			$revision_line = $options[$revision_index].Split("`"")
			$revision_line[2] = $revision_line[2].Replace(":", "").Replace(",", "")
			$revision_line[2] = ":$revision,"
			$options[$revision_index] = $revision_line -join "`""
			
		}
		
		$options_string = $options -join "`n"
		
		Set-Content -NoNewline -Path $options_path -Value $options_string
		
	}
	
	writeVersion -options_path $options_path -version $version_string -revision $revision_string
	
}

function setVersionForAllOptions([Version] $version) {
	
	setVersion -options_path $global:master_options_path -version $version
	
	foreach ($options_path in $global:managed_options_paths) {
		
		setVersion -options_path $options_path -version $version
		
	}
	
}

#endregion Functions


# Apply options AFTER functions definitions and BEFORE main script body
# (powershell doesn't have "forward declaration" , so i achieved a simmilar effect with "deferred execution")
applyScriptOptions


#region Main script part

# Note
# ConvertFrom-Json/ConvertTo-Json are simplier to use but they have different json formating comparing to gamemaker

if ($GetVersion) {
	
	if ($VersionAsString) {
		return (getVersion -options_path $global:master_options_path).ToString()
	}
	
	return getVersion -options_path $global:master_options_path
	
} elseif ($SetVersion -ne "") {
	
	setVersionForAllOptions -version (New-Object -TypeName Version -ArgumentList @($SetVersion))
	
}

$curent_version = getVersion -options_path $global:master_options_path

$prompt = "Current version is `"$curent_version`" . What will be a new one ?"
$result = ""

if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
	$result = readHostWithEditableDefault -prompt $prompt -default_value "$curent_version"
} else {
	$result = Read-Host -Prompt $prompt
}

if ($result -eq "") {
	Write-Error -Message "Canceled due to empty prompt result"
	exit
}

$new_version = New-Object -TypeName Version -ArgumentList @($result)

if ($new_version -eq $null) {
	Write-Error -Message "User supplied version are invalid !"
	exit
}

setVersionForAllOptions -version $new_version

#endregion Main script part