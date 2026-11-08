# Opens DK Bananza. On NVIDIA it uses the card and the stage skip list that avoid its device loss; the list was tested only on an RTX 5090.
Set-Location (Join-Path $PSScriptRoot "..\build\dkb100")
if (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' }) {
    if (-not $env:TOTK_GPU_NAME) { $env:TOTK_GPU_NAME = "NVIDIA" }
    # Upstream skips by vertex or fragment stage; this list does not record which stage each hash was, so it goes in both
    $l = "fb6e80e4f0bd1ac5,140a1eac75f7b5c0,163bd4735277403a,f7d00699dae00a95,0e11b0ec10da5ba9,f97309e8c87bb4de,9d968c53a40627d1,a0c3abb12477b0d6,0935b40c3f9bae0d,3fe2565417ad0bf1,2b4d4b1fc1752cfb,dab38509f781bfc9,b1c4eab4cdef0e08,f5f19569286aa241,837fa78832bcb26c,a69f7bf0ed02424b"
    $env:DKB_SKIP_VS = $l; $env:DKB_SKIP_FS = $l
}
.\dkb.exe @args
