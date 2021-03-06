   $ver = "1.0.5"
   
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Clear-Host

    $pathSettings = "$PSScriptRoot\setting.json"
    $pathLog = "$PSScriptRoot\log.txt"
    $settings = $null

    $counterSend = 0 
    $counterPing  = 0

    function LoadConfig{
    
    $tmpSettings = $settings
    
        try{
    
        $global:settings = ConvertFrom-Json (Get-Content $pathSettings -Raw)

        
    }catch{

        $global:settings = $tmpSettings

        }
    }

    function PrintAndSaveMessage ($text,[switch]$Out) {

        $DTime = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        $messag = "$DTime - $text ("+ $settings.NameRig + ")"
        Write-Host $messag
        
        if($settings.Log){
        
            $messag | out-file $pathLog -append
        
        }
        
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
    
    LoadConfig

    $settings.varAmountReboot = $tmpSettings.varAmountReboot
    ConvertTo-Json $settings | Out-File $pathSettings

    }

    function StartReboot {
                
        if($settings.varAmountReboot -le $settings.AmountReboot){
                
                PrintAndSaveMessage "перезагрузка"

                    $global:settings.varAmountReboot++
                    SaveConfig
                    Start-Sleep -Second 3

                    Restart-Computer -Force
                
                }else {

                PrintAndSaveMessage "Ожидание"

                $global:settings.varAmountReboot--
                SaveConfig
                Start-Sleep -Second ($settings.SleepRepeatReboot * 60)

                    }
    }

    function StartMiner {
    
    SendTelegram ("Стартуем майнер")

    LoadConfig

    
    if (Get-Process -Name "nbminer" -ErrorAction SilentlyContinue) {

        Stop-Process -processname "nbminer"
        SendTelegram ("Остановка майнера")    
    }

        Start-Sleep -Seconds 2

        switch ($settings.BatMiner.start) {

            "rvn" { $batMiner = $settings.BatMiner.rvn }
            "eth" { $batMiner = $settings.BatMiner.eth }
            Default { SendTelegram ("Ошибка выбора пути майнера")}
        }

    try {

        Set-Location $settings.FolderMiner
        Start-Process -FilePath $batMiner

    }
    catch {

        SendTelegram ("Ошибка старта майнера '$batMiner'")
        return $false
    }

    SendTelegram ("Запущен майнер '$batMiner'")
    return $true

    }

#---------------------------Старт-------------------------------------------------------------------------

LoadConfig


do{  

        if(SendTelegram ("СТАРТ МОНИТОРИНГА"))
        {
            
        $counterSend = 0
        $settings.varAmountReboot = 0
        SaveConfig

        break;
        }
   
    if ($counterSend -ge 10) #!!!!!!!!!!!!!!!!!!!!!!!!!
    {
        PrintAndSaveMessage "перезагрузка при старте"
        StartReboot
    }

    $counterSend++
    Start-Sleep -Second 10

        }while (1)


Start-Sleep -Second 60

##if(-not (StartMiner)) { return }

StartMiner

Start-Sleep -Second 15



#помчали
while (1) {
      
    $tSettings = $settings
    LoadConfig

    if ($settings.BatMiner.start -ne $tSettings.BatMiner.start){

        StartMiner
    }

        if (test-Connection -ComputerName $settings.PingSite -Count 3 -Quiet) {

            PrintAndSaveMessage "успешно потыкан палочкой и отзывается"
            $counterPing  = 0

        }
        else {

            PrintAndSaveMessage "плохо пахнет и не отзывается" 
            $counterPing++

            if ($counterPing -ge 10) {

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


    


