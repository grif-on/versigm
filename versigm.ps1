$options_path = "../options/windows/options_windows.yy"

# Note
# ConvertFrom-Json/ConvertTo-Json are simplier to use but they have different json formating comparing to gamemaker

$options = Get-Content -Path $options_path

# testing
$version_line = $options[31].Split("`"")
$version_line[3] = "yes"
$options[31] = $version_line -join "`""

$options_string = $options -join "`n"

Set-Content -NoNewline -Path $options_path -Value $options_string