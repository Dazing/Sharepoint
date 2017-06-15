#
# Script.ps1
#

# Connect to SP Enviroment

# Get all active sites

# Run jobs 

Clear-Host

Write-Host "Creating variables.. `n"
[System.Collections.ArrayList]$siteList = @(1..10000)
$listCounter = 0

$CPU = Get-WmiObject Win32_Processor
$threads = $CPU.NumberOfLogicalProcessors

[System.Collections.ArrayList]$workers = @(
)

$mtxRead = New-Object System.Threading.Mutex($false)
$mtxWrite = New-Object System.Threading.Mutex($false)

[System.Collections.ArrayList]$listResult = @(
)

[System.Management.Automation.ScriptBlock]$workerScriptBlock = {
		param($workerMtxRead, $workerMtxWrite, $workerListResult)

		$OFS = ','
		
		[System.Collections.ArrayList]$workerList = @()
		[System.Collections.ArrayList]$workerSiteList = @()
		while($listCounter -lt $siteList.Count){
			$workerMtxRead.WaitOne(10000)  # Obtain access to site list
			$siteListCount = $siteList.Count
			if($siteListCount-eq 0){break} #Double check if list is empty
			if($siteListCount -ge 3){
				$workerSiteList = $siteList[$listCounter..($listCounter+10)]
				$listCounter = $listCounter+3
				
			}
			else {
				$workerSiteList = $siteList[0..($siteListCount-1)]
			}

			$workerMtxRead.ReleaseMutex()

			for($j = 0;$j -lt $workerSiteList.Count;$j++){
				$workerSiteList[$j] = $workerSiteList[$j]*2
			}

			$workerMtxWrite.WaitOne(100000) 

			$workerListResult.Add($workerSiteList[0..2])

			$workerMtxWrite.ReleaseMutex()

		}
		

	}

Write-Host "Creating workers.. `n"



for($i = 0;$i -lt $threads;$i=$i+1){
	
	# Spawn workers (jobs)
	$worker = Start-Job -Name "worker_$i" -ScriptBlock $workerScriptBlock -ArgumentList $mtxRead,$mtxWrite,$listResult
	#$worker = start-job -Name "worker_$i" -ScriptBlock $workerScriptBlock | wait-job | receive-job 


	$workers.Add($worker)
}


Invoke-Command $workerScriptBlock -ArgumentList $mtxRead,$mtxWrite,$listResult


Write-Host "Workers created `n"

<#
for($i = 0;$i -lt $threads;$i=$i+1){
	$jobEvent = Register-ObjectEvent -InputObject $workers[$i] -EventName StateChanged -Action {
		Write-Host ('Job #{0} ({1}) complete.' -f $sender.id, $sender.Name)
		#Write-Host "HGej"
		
		$complete = $true
		foreach($worker in $workers){
			if($worker.State -ne "Completed"){
				$complete = $false
				break
			}
		}

		if($complete -eq $true){
			Write-Host "Jobs completed:"
			$listResult
		}

		Write-Host ($sender | Format-Table | Out-String)
	}
}
#>
Write-Host "Sleeping `n"

sleep(3)

$mtxWrite.WaitOne(5000)

Write-Host "Printing list after 5 sec:"
$listResult

$mtxWrite.ReleaseMutex()
