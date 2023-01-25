$Location = "South Africa North"

$publisher = "MicrosoftWindowsServer"
Get-AzVMImageOffer -Location $location -PublisherName $publisher | Select-Object Offer

$offer = "WindowsServer"
Get-AzVMImageSku -Location $location -PublisherName $publisher -Offer $offer | Select-Object Skus