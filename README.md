# S2SELECT.X
## 概要

X68000のSCSIバスプロトコルを、**SCSI2**っぽくします。  
いままで使えなかった**SCSI2**デバイスが使えるようになります。

本パッチはSCSI IOCSの隙間に入り込むためメモリ消費はありません。そのためSCSI IOCSの書き換え可能な環境が必要です。

## 対応する環境
* X68000ではSCSI IOCSがSCHDISK v1.04になっている必要があります。  
* X68030では030SYSpatch.x v0.40 以降の環境が必要です。  
* 040turboでは040SYSpatch.x(040SRAMpatch.r) v2.60 以降の環境が必要です。  

上記以外の環境には対応しません。  
その他、詳しいことは付属のドキュメントを参照してください。  
