﻿gwmi -class Lenovo_BiosSetting -namespace root\wmi | ForEach-Object {if ($_.CurrentSetting -ne "") {Write-Host $_.CurrentSetting.replace(","," = ")}}