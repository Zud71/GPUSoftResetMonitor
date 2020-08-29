   #ver 1.0.4
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Clear-Host

    $counterGlobal  = 0
    $counterGPU = 0;

    $pathSettings = "$PSScriptRoot\setting.json"
    $settings = ConvertFrom-Json (Get-Content $pathSettings -Raw)


    function PrintAndSaveMessage ($text,[switch]$Out) {

        $DTime = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        $messag = "$DTime - $text ("+ $settings.NameRig + ")"
        Write-Host $messag
        $messag| out-file $settings.LogFile -append
    
        if ($Out){ return $messag }

    }
    function SendTelegram ($text,[switch]$Out) {

    try {

        $messag = PrintAndSaveMessage $text -Out

        $URI = "https://api.telegram.org/bot" + $settings.Token + "/sendMessage?chat_id=" + $settings.ChatId + "&text=" + $messag
        $response = Invoke-WebRequest -URI ($URI)
        

        }catch
        {
            return $false
        } 

        return $true
    }

    function SaveConfig {
    $tmpSettings = $settings
    $settings = ConvertFrom-Json (Get-Content $pathSettings -Raw)
    $settings.varAmountReboot = $tmpSettings.varAmountReboot

    ConvertTo-Json $settings | Out-File $pathSettings
    }

    function StartReboot {
                
        if($settings.varAmountReboot -le $settings.AmountReboot){
                
                PrintAndSaveMessage "перезагрузка"

                    $settings.varAmountReboot++
                    SaveConfig
                    Start-Sleep -Second 3

                    Restart-Computer -Force
                
                }else {

                $settings.varAmountReboot--
                SaveConfig
                Start-Sleep -Second ($settings.SleepRepeatReboot * 60)

                    }
    }

    #Старт
    do{  

        if(SendTelegram ("СТАРТ МОНИТОРИНГА"))
        {
            break;
        }
   
    if ($counterGlobal -ge 10) 
    {
        PrintAndSaveMessage "перезагрузка при старте"
        StartReboot
    }

    $counterGlobal++
    Start-Sleep -Second 10

        }while (1)

$counterGlobal  = 0
Start-Sleep -Second 60

try{

    Set-Location $settings.FolderMiner
    Start-Process -FilePath $settings.BatMiner

}catch{

    SendTelegram ("Ошибка старта майнера")
    return
}
Start-Sleep -Second 15

SendTelegram ("Старт майнера")

while (1) {
    
        if (test-Connection -ComputerName $settings.PingSite -Count 3 -Quiet) {

            PrintAndSaveMessage "успешно потыкан палочкой и отзывается"
            $counterGlobal  = 0

        }
        else {

            PrintAndSaveMessage "плохо пахнет и не отзывается" 
            $counterGlobal++

            if ($counterGlobal -ge 10) {

            StartReboot

            }
            
        }

         #количество gpu 
        try {
            $Request = Invoke-WebRequest -URI ($settings.URICard) 
            $dataJson = ConvertFrom-Json $Request
            $amountGPU = $dataJson.miner.devices.Count
        }
        catch {

            SendTelegram ("Отвал майнера")

        }

        #температура    
        try {

            $Request = Invoke-WebRequest -URI ($settings.URIInfo) 
            $dataJson = ConvertFrom-Json $Request


            foreach ( $item in $dataJson.Children[0].Children) {

                if ($item[0].Text.ToLower().Contains("nvidia") ) {
                    
                    $tempVal = $item[0].Children[1].Children[0].Value.Remove(2)
                   
                    if ( $tempVal -ge $settings.MaxTemper) {

                        SendTelegram "Высокая температура: $tempVal"

                    }else{

                        if ( $tempVal -le 20) {

                        SendTelegram "Низкая температура: $tempVal"

                        }
                    }
                }

            }

        }
        catch {
        }

        #----------------------------
        if ($amountGPU -ne $settings.CardAmount) {
            $counterGPU++;

            SendTelegram ("Отвал видяхи")

            if ($counterGPU -ge $settings.CounterCardRepeatWhenReboot) {

                SendTelegram ("Перезагрука по отвалу")

                Restart-Computer -Force 
            }
	
        }
        else {
    
            $counterGPU = 0;    
        }

        Start-Sleep -Second 60
    }


    


