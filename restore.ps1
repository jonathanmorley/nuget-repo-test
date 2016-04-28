Param (
	[Parameter(Mandatory = $true)]
	$url,
	$nugetVersion = '3.4.3',
	$concurrency = 1
)

function Get-ScriptDirectory
{
    Split-Path $script:MyInvocation.MyCommand.Path
}

$packagesFile = Join-Path (Get-ScriptDirectory) packages.config

$nuget = Join-Path (Get-ScriptDirectory) "nuget.$($nugetVersion).exe"

$jobNames = $(1..$concurrency) |% { "restore_$_" }
Remove-Job -Name ($jobNames |? { Get-Job -Name $_ -ErrorAction SilentlyContinue })

$(1..$concurrency) |% {
	$packagesDir = Join-Path (Get-ScriptDirectory) "packages_$_"

	Start-Job -Name "restore_$_" -ScriptBlock {
		Param (
			$nuget,
			$url,
			$packagesDir,
			$packagesFile
		)

		$env:NUGET_PACKAGES = "$packagesDir-cache"

		Remove-Item -Recurse -Force $env:NUGET_PACKAGES
		Remove-Item -Recurse -Force $packagesDir

		& $nuget restore $packagesFile `
			-NoCache `
			-PackagesDirectory $packagesDir `
			-Source $url `
			-Verbosity "quiet"
		if ($LASTEXITCODE -ne 0) {
			Throw "Restore failed."
		}
	} -ArgumentList @($nuget, $url, $packagesDir, $packagesFile)
}

Measure-Command { $jobs = Wait-Job -Name $jobNames }
If ($jobs |? { $_.State -eq 'Failed' }) {
	Throw 'Restores failed.'
}
