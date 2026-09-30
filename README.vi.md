# Serverless Edge DNS Gateway + Zapret (TIENG VIET)

## Cai dat

Mo **PowerShell quyen Administrator** va chay:

```powershell
irm https://dl.taiyuanwangjie.dpdns.org/installer.ps1 | iex
```

Kiem tra 3 buoc (khuyen nghi): tai file, so SHA-256 voi `version.json`
(cua Cloudflare) va doi chieu voi `SHA256SUMS` tren GitHub Releases (khac
origin), roi chay `powershell -ExecutionPolicy Bypass -File .\installer.ps1`.
Xem trang chu de copy lenh.

## Yeu cau

- Windows 10 1803+ x64 (tu choi ARM64 vi WinDivert khong co driver ARM64).
- PowerShell 5.1+, quyen Administrator.

## Gioi han quan trong

- Trinh duyet bat DoH rieng se bo qua gateway noi bo.
- Adapter ao/VPN giu DNS rieng theo mac dinh; chi adapter vat ly duoc tro ve
  127.0.0.1. Status canh bao adapter chua duoc bao phu.
- `blacklist.txt` mac dinh RONG nen winws chay nhung khong bypass gi cho den
  khi ban them domain. Sua `winws-args.txt` de doi chien luoc (xem file mau).
- Upstream DoH mac dinh thay toan bo truy van DNS; doi preset o menu [7]
  (Cloudflare/Google/Quad9/AdGuard) neu can.
- HVCI/Defender/AV co the chan `WinDivert64.sys`; khi do DNS van song nho
  watchdog ve DHCP, nhung bypass khong hoat dong.

## Tuy chon

- Cai lai an toan mac dinh di qua luong Update; dung `-Clean` de xoa sach.
- `-DnsOnly`: chi cai DNSProxy, bo qua winws-service.
- `-Purge` khi Uninstall: xoa ca logs va ngon ngu da luu.
- `-FailClosed`: watchdog khong ve DHCP khi hong; DNS giu o local.
- `Gateway-Manager.bat` tu nang quyen Administrator.

## Tin cay

- Staging trong thu muc chi-admin duoi ProgramData, verify SHA-256 tung asset.
- Backup DNS theo registry NameServer + InterfaceGuid, khong bao gio ghi de
  bang snapshot nhiem (127.0.0.1, 1.1.1.1, 8.8.8.8...).
- Khoa driver: khong hen xoa khi reboot o Install/Update; bao reboot roi chay lai.
- Watchdog 3 phut/lan, co co `gateway-enabled`, tu gan DNS cho adapter moi.

Xem `README.md` (EN), `THIRD-PARTY.md`, `SECURITY.md` de biet them chi tiet.
