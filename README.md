link-memo.el -- 指定されたディレクトリ内のファイルへのリンクをはる elisp です。

# About

Emacs 上で Wiki っぽいことを実現しようとしたものです。
指定されたディレクトリ内にあるファイル名をメモ名とみなし、
バッファ内でメモ名にマッチする文字列にリンクを貼ります。
minor-mode として動作しまので、
text-mode + link-memo とか markdown-mode + link-memo のような使い方が可能です。

## Note

ファイル名をメモ名 (ページ名) とみなすので、ファイルシステムの制限をモロに受けます。
UNIX 系のファイルシステムで多くの場合は大文字と小文字が区別され、
一部ファイルシステムではマルチバイト文字を使用できないかもしれません。
ファイルシステムによって使用できない文字も異なりますが、そのへんも吸収してません。

# Download

[tonjiru/link-memo](https://github.com/tonjiru/link-memo) から link-memo.el をダウンロードしてください。

# Installation & Configuration

load-pathの通っているディレクトリに link-memo.el を入れてください。

以下の行を emacs.d/init.el (or .emacs) に追加してください。

``` elisp
(load "link-memo")
```

以下のようにカスタマイズするとより便利かもしれません
``` elisp
;; デフォルトの "~/LinkMemos/" 以外にファイルを置く場合。
(setq link-memo-dir
      '(("memo" . "~/Wiki/")
        ("hexo" . "~/blog/hexo/tonjiru/source/_posts/")
     ))
(setq link-memo-extension-list
      '(("memo" . "txt")
        ("hexo" . "md")
     ))
;; モードラインの文字が"LiMe"じゃない方がいい場合
(setq link-memo-mode-line-string " @")
;; 上記設定 (特にlink-memo-dir) は load より前に記述を。
(load "link-memo")
;; link-memo-dir以外のファイルでも一時的にリンクを張るときに便利。
(global-set-key "\C-ck" 'link-memo-mode)
;; 各種キー設定
(global-set-key "\C-c\C-k\C-s" 'link-memo-search)
(global-set-key "\C-c\C-k\C-q" 'link-memo-query)
(global-set-key "\C-c\C-k\C-i" 'link-memo-index)
(global-set-key "\C-c\C-k\C-f" 'link-memo-find-file)
(global-set-key "\C-c\C-k\C-v" 'link-memo-view-file)
```
