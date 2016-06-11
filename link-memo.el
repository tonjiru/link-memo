;;; link-memo.el --- Link memo mode

;; Author: Tonjiru <gudakusan@tonjiru.org>
;; Keywords: convenience hypermedia wp link-memo wiki

;; Copyright (c) 2005-2016 Tonjiru <gudakusan@tonjiru.org>
;; Permission to use, copy, modify, distribute, and sell this software and its
;; documentation for any purpose is hereby granted without fee, provided that the
;; above copyright notice appear in all copies and that both that copyright notice
;; and this permission notice appear in supporting documentation.  No
;; representations are made about the suitability of this software for any purpose.
;; It is provided "as is" without express or implied warranty.

;; Copyright (c) 2005-2016 Tonjiru <gudakusan@tonjiru.org>
;; 本プログラムはフリー・ソフトウェアです。あなたは，Free Software Foundation が公表
;; した GNU 一般公有使用許諾の「バージョン ２」或いはそれ以降の各バージョンの中から
;; いずれかを選択し，そのバージョンが定める条項に従って本プログラムを再頒布または変
;; 更することができます。本プログラムは有用とは思いますが，頒布にあたっては，市場性
;; 及び特定目的適合性についての暗黙の保証を含めて，いかなる保証も行ないません。詳細
;; については GNU 一般公有使用許諾書をお読みください。

;;; Commentary:

;; About:
;; Emacs 上で Wiki っぽいことを実現しようとしたものです。
;; 指定されたディレクトリ内にあるファイル名をメモ名とみなし、
;; バッファ内でメモ名にマッチする文字列にリンクを貼ります。
;; minor-mode として動作しまので、
;; text-mode + link-memo とか markdown-mode + link-memo のような使い方が可能です。
;;
;; Note:
;; ファイル名をメモ名(ページ名)とみなすので、ファイルシステムの制限をモロに受けます。
;; Unix系のファイルシステムで多くの場合は大文字と小文字が区別され、
;; 一部ファイル・システムではマルチバイト文字を使用できないかもしれません。
;; ファイルシステムによって使用できない文字も異なりますが、そのへんも吸収してません。
;;
;; Installation:
;; load-pathの通っているディレクトリにlink-memo.elを入れてください。
;;
;; Configuration:
;; 以下の行を.emacsに追加してください。
;; ----
;; (load "link-memo")
;; ----
;;
;; 以下のようにカスタマイズするとより便利かもしれません
;; ----
;; ;; "~/LinkMemos/"以外のディレクトリにファイルを置く場合。
;; (setq link-memo-dir
;;       '(("memo" . "~/Wiki/")
;;         ("hexo" . "~/blog/hexo/tonjiru/source/_posts/")
;;      ))
;; (setq link-memo-extension-list
;;       '(("memo" . "txt")
;;         ("hexo" . "md")
;;      ))
;; ;; モードラインの文字が"LiMe"じゃない方がいい場合
;; (setq link-memo-mode-line-string " @")
;; ;; 上記設定(特にlink-memo-dir)はloadより前に記述を。
;; (load "link-memo")
;; ;; link-memo-dir以外のファイルでも一時的にリンクを張るときに便利。
;; (global-set-key "\C-ck" 'link-memo-mode)
;; ;; 各種キー設定
;; (global-set-key "\C-c\C-k\C-s" 'link-memo-search)
;; (global-set-key "\C-c\C-k\C-q" 'link-memo-query)
;; (global-set-key "\C-c\C-k\C-i" 'link-memo-index)
;; (global-set-key "\C-c\C-k\C-f" 'link-memo-find-file)
;; (global-set-key "\C-c\C-k\C-v" 'link-memo-view-file)
;; ----

;;; Code:

(defvar link-memo-dir
  '(("My" . "~/LinkMemos/"))
  "`link-memo-mode' を自動的に有効にするディレクトリ。
リンク先情報もここから読み込む。")

(defvar link-memo-mode nil
  "link-memo minor mode.")

(defvar link-memo-pagenames '("FrontPage" "SandBox")
  "link-memo page names.")

(defvar link-memo-extension "txt"
  "ファイルの拡張子。
拡張子の異なるファイルは基本的に無視します。")

(defvar link-memo-extension-alist nil
  "ファイルの拡張子。
拡張子の異なるファイルは基本的に無視します。
ドメイン毎に指定可能です。省略した場合は `link-memo-extension' を使用します。")

(defvar link-memo-mode-line-string " LiMe"
  "mode-lineに表示する文字。")

(defvar link-memo-pagenames-regexp-cache  nil
  "`link-memo-pagenames'をregexp-optした文字列。")

(defvar link-memo-pagenames-regexp-cache-build-time nil
  "`link-memo-pagenames-regexp-cache'を作成した時間。")

(defvar link-memo-pagenames-modify-time nil
  "`link-memo-pagenames'を変更した時間。")

(defvar link-memo-verbose nil
  "nil以外の場合、`link-memo-highlight-buffer'をやかましくする。")

(defvar link-memo-link-indicator "^"
  "リンクに表示する記号。")

;; TODO: `defface' に変更を。
(make-face 'link-memo-link-face)
;;(set-face-foreground 'link-memo-link-face "#0080e0")
;; (set-face-underline-p 'link-memo-link-face t)
(set-face-underline 'link-memo-link-face t)

(defun link-memo-mode (&optional arg)
  "Toggle link-memo minor mode."
  (interactive "P")
  (setq link-memo-mode
	(if (null arg) (not link-memo-mode) ; 引数がnullなら、現在と逆の状態にする。
	  (> (prefix-numeric-value arg) 0)))
  (if link-memo-mode
      (let ((dirs link-memo-dir)
	    (dir)
	    (domain "-"))
	(if buffer-file-name
	    (while dirs
	      (setq dir (cdar dirs))
	      (if (string= (expand-file-name (file-name-directory buffer-file-name))
			   (expand-file-name dir))
		  (setq domain (caar dirs)))
	      (setq dirs (cdr dirs))))
	(make-local-variable 'link-memo-mode-line-string)
	(setq link-memo-mode-line-string (format "%s:%s" link-memo-mode-line-string domain))
	(or (assq 'link-memo-mode minor-mode-alist)
	    (setq minor-mode-alist
		  (cons '(link-memo-mode link-memo-mode-line-string) minor-mode-alist)))
	;; 強調表示する
	(link-memo-highlight-buffer)
	;; 変更時フック
	(if (fboundp 'make-local-hook)
	    (make-local-hook 'after-change-functions))
	(add-hook 'after-change-functions 'link-memo-after-change-function nil t))
    (progn
      ;; 変更時フック削除
      (remove-hook 'after-change-functions 'link-memo-after-change-function t)
      ;; 強調表示を解除する
      (link-memo-unhighlight-buffer)))
  (force-mode-line-update))

;; バッファ全体を強調表示する。
(defun link-memo-highlight-buffer ()
  "Highlighting buffer."
  (interactive)
  (if link-memo-mode
      (let ((buffer-undo-list t)	; アンドゥ無効化
	    (inhibit-read-only t) ; リードオンリーのテキストにも書き込む
	    (inhibit-point-motion-hooks t) ; 変更時のフックを無効化
	    (inhibit-modification-hooks t) ; 変更時のフックを無効化
	    (modified-p (buffer-modified-p))) ; 変更フラグのバックアップ
	(unwind-protect
	    (save-excursion
	      (save-restriction
		(widen)
		(link-memo-highlight-region (point-min) (point-max) link-memo-verbose)))
	  (set-buffer-modified-p modified-p))) ; 変更フラグの復元
    (error "Not link-memo-mode")))

(defun link-memo-make-link (bp ep name)
  "リンクを張る."
  (let ((ol (make-overlay bp ep)))
    (overlay-put ol 'face 'link-memo-link-face)
    (overlay-put ol 'category 'link-memo-link)
    (overlay-put ol 'evaporate t)
    (overlay-put ol 'after-string link-memo-link-indicator)
    (add-text-properties bp ep
			 `( ;; face
			   ;; underline
			   ;; (foreground-color . "blue")
			   ;; mouse-face
			   ;; (background-color . "#c0c0ff")
			   link-memo-link
			   ,name))))

(defun link-memo-highlight-region (region-beg region-end &optional verbose)
  "Highlighting region."
  (let ((bp)
	(ep))
    ;; ハイライト解除
    (link-memo-unhighlight-region region-beg region-end)

    ;; リージョンの先頭へ移動
    (goto-char region-beg)
    ;; ページ名を検索して
    (while (re-search-forward (link-memo-pagenames-regexp) region-end t)
      ;; ハイライト
      (if verbose (message "link-memo highlighting...%s" (match-string 0)))
      (setq bp (match-beginning 0))
      (setq ep (match-end 0))
      (link-memo-make-link bp ep (match-string 0)))
    (if verbose (message "link-memo highlighting...done"))))

(defun link-memo-unhighlight-buffer ()
  "Unhighlighting buffer."
  (interactive)
  (let ((buffer-undo-list t)		; アンドゥ無効化
	(inhibit-read-only t)	; リードオンリーのテキストにも書き込む
	(inhibit-point-motion-hooks t)	; 変更時のフックを無効化
	(inhibit-modification-hooks t)	; 変更時のフックを無効化
	(modified-p (buffer-modified-p))) ; 変更フラグのバックアップ
    (unwind-protect
	(save-excursion
	  (save-restriction
	    (widen)
	    (link-memo-unhighlight-region (point-min) (point-max))))
      (set-buffer-modified-p modified-p)))) ; 変更フラグの復元

(defun link-memo-unhighlight-region (region-beg region-end)
  "Unhighlighting region."
  (let ((ols (overlays-in region-beg region-end))
	(ol))
    (while ols
      (setq ol (car ols))
      (if (eq (overlay-get ol 'category)
	      'link-memo-link)
	  (delete-overlay ol))
      (setq ols (cdr ols)))
    (remove-text-properties region-beg region-end
			    '(;; face
			      ;; nil
			      ;; mouse-face
			      ;; nil
			      link-memo-link
			      nil))))

(defun link-memo-add-pagename (pagename with-sort)
  "Add paganema to link-memo-pagenames."
  ;; 登録済みの場合nilを返す
  (if (member pagename link-memo-pagenames)
      nil
    (progn
      ;; 未登録の場合
      ;; リストに追加
      (setq link-memo-pagenames
	    (append (list pagename)
		    link-memo-pagenames))
      (setq link-memo-pagenames-modify-time
	    (current-time))
      ;; ソート
      (if with-sort (link-memo-sort-pagename)))))

(defun link-memo-sort-pagename ()
  "Make pagename table."
  (setq link-memo-pagenames (sort link-memo-pagenames 'string<)))

(defun link-memo-make-pagename-table ()
  "Make pagename table."
  ;; クリアする
  (setq link-memo-pagenames '())
  ;; ディレクトリ内をとりあえず読み込む。
  (let ((dirs link-memo-dir)
	(dir))
    (while dirs
      (setq dir (cdar dirs))
      (setq domain (caar dirs))
      (let ((files (directory-files (expand-file-name dir) t))
	    (file))
	(while files
	  (setq file (car files))
	  ;; 有効なファイル名のみ登録する
	  (if (link-memo-is-valid-file domain file)
	      (progn
		;; ファイル名部分だけを抜き出して登録
		;; (ソート済のものを処理するので link-memo-add-pagename でのソート不要)
		(link-memo-add-pagename
		 (file-name-sans-extension (file-name-nondirectory file)) nil)))
	  (setq files (cdr files))))
      (setq dirs (cdr dirs)))
    ;; 最後にソート
    (link-memo-sort-pagename)))

(defun link-memo-after-change-function (region-beg region-end old-len)
  "modification hook."
  (let (
	(inhibit-point-motion-hooks t)	; 変更時のフックを無効化
	(buffer-undo-list t)		; アンドゥ無効化
	(inhibit-read-only t)	; リードオンリーのテキストにも書き込む
	(inhibit-modification-hooks t)	; 変更時のフックを無効化
	(modified-p (buffer-modified-p)) ; 変更フラグのバックアップ
	(bp)
	(ep))
    (unwind-protect
	(save-excursion
	  (save-match-data
	    (save-restriction
	      (widen)
	      ;; ハイライト開始位置を終了位置
	      ;; 開始位置は行頭から
	      ;; ちなみに font-lock は開始位置の行頭から終了位置+1だった。
	      (goto-char region-beg)
	      (beginning-of-line)
	      (setq bp (point))
	      ;; 終了位置は行末
	      (goto-char region-end)
	      (end-of-line)
	      (setq ep (point))
	      ;; ハイライト
	      (link-memo-highlight-region bp ep nil)))
	  (set-buffer-modified-p modified-p))))) ; 変更フラグの復元

(defun link-memo-jump-to-link ()
  "リンク先に飛ぶ。"
  (interactive)
  (let ((page)
	(domain))
    ;; 現在位置のテキストのプロパティからリンク先を抽出
    (setq page (get-text-property (point) 'link-memo-link))
    (setq domain (get-text-property (point) 'link-memo-domain))
    ;; リンク先を開く。(とりあえずは、find-file で処理する。)
    (if page
	(progn
	  (find-file (link-memo-expand-file-name page domain))
	  )
      (error "Current point is not link"))))

(defun link-memo-jump-to-link-other-frame ()
  "リンク先に飛ぶ。その際に新しいフレームを開く"
  (interactive)
  (let ((page)
	(domain))
    ;; 現在位置のテキストのプロパティからリンク先を抽出
    (setq page (get-text-property (point) 'link-memo-link))
    (setq domain (get-text-property (point) 'link-memo-domain))
    ;; リンク先を開く。(とりあえずは、find-file で処理する。)
    (if page
	(progn
	  ;; (message "Jump to %s..." page)
	  ;; TODO: なんかdomainの考慮が抜けているような... (他の関数も同様)
	  (find-file-other-frame (link-memo-expand-file-name page domain))
	  ;; (message "Jump to %s...done" page))
	  (error "Current point is not link")))))

(defun link-memo-jump-to-link-other-window ()
  "リンク先に飛ぶ。その際に新しいウィンドウを開く"
  (interactive)
  (let ((page)
	(domain))
    ;; 現在位置のテキストのプロパティからリンク先を抽出
    (setq page (get-text-property (point) 'link-memo-link))
    (setq domain (get-text-property (point) 'link-memo-domain))
    ;; リンク先を開く。(とりあえずは、find-file で処理する。)
    (if page
	(progn
	  ;; (message "Jump to %s..." page)
	  (view-file-other-window (link-memo-expand-file-name page domain))
	  ;; (message "Jump to %s...done" page)
	  )
      (error "Current point is not link"))))

(defun link-memo-jump-to-link-view ()
  "リンク先を表示する。"
  (interactive)
  (let ((page)
	(domain))
    ;; 現在位置のテキストのプロパティからリンク先を抽出
    (setq page (get-text-property (point) 'link-memo-link))
    (setq domain (get-text-property (point) 'link-memo-domain))
    (if page
	(progn
	  ;; (message "Jump to %s..." page)
	  (view-file (link-memo-expand-file-name page domain))
	  ;; (message "Jump to %s...done" page)
	  )
      (error "Current point is not link"))))

(defun link-memo-search-this-page ()
  "現在開いているページ名で検索。"
  (interactive)
  (link-memo-search (file-name-sans-extension(buffer-name))))

(defun link-memo-is-valid-file (domain file)
  (let ((ext (cdr (assoc domain link-memo-extension-alist))))
    (if (not ext) (setq ext link-memo-extension))
    (and (not (file-directory-p file)) ; ディレクトリを除外
	 (string-match
	  (concat "^.*\\." ext "$")
	  (file-name-nondirectory file)) ; 指定された拡張子のみを許可
	 (not (backup-file-name-p file)) ; バックアップファイルを除外
	 (not (string-match "^#.+#$" (file-name-nondirectory file))))))

(defun link-memo-search (search-word)
  "検索"
  (interactive "ssearch:")
  (let ((dirs link-memo-dir)
	(dir)
	(domain)
	(name)
	(matched-pages nil))
    (save-excursion
      (save-restriction
	(message "Search %s..." search-word)
	(while dirs
	  (setq dir (cdar dirs))
	  (setq domain (caar dirs))
	  (let ((files (directory-files (expand-file-name dir) t))
		(file))
	    (while files
	      (setq file (car files))
	      ;; 有効なファイル名のみ検索する
	      (if (link-memo-is-valid-file domain file)
		  (progn
		    (setq name (file-name-sans-extension (file-name-nondirectory file)))
		    (message "Search %s in %s..." search-word name)
		    ;; 本文を検索
		    (if (link-memo-search-text domain name search-word)
			(setq matched-pages (append `((,name . ,domain)) matched-pages))
		      )))
	      (setq files (cdr files))))
	  (setq dirs (cdr dirs)))))
    (if matched-pages
	(progn
	  (link-memo-list-pages "*SearchResult*" (concat "Search : " search-word) matched-pages)
	  (message "Search %s...done" search-word))
      (error "Search %s...not found" search-word))))

(defun link-memo-search-text (domain name search-word &optional regexp)
  "検索"
  (with-temp-buffer
    ;; ページ名の文字列もテンポラリバッファに突っ込んで検索対象にする。
    (insert name "\n")
    (insert-file-contents (link-memo-expand-file-name name domain))
    (goto-char (point-min))
    (if regexp
	(re-search-forward search-word nil t)
      (search-forward search-word nil t))))

(defun link-memo-query (page word)
  "検索"
  (interactive "squery page name(regexp): \nsquery word(regexp): ")
  (let ((dirs link-memo-dir)
	(dir)
	(domain)
	(name)
	(matched-pages nil))
    (save-excursion
      (save-restriction
	(message "Query %s in %s ..." word name)
	(while dirs
	  (setq dir (cdar dirs))
	  (setq domain (caar dirs))
	  (let ((files (directory-files (expand-file-name dir) t))
		(file))
	    (while files
	      (setq file (car files))
	      ;; 有効なファイル名のみ検索する
	      (if (link-memo-is-valid-file domain file)
		  (progn
		    (setq name (file-name-sans-extension (file-name-nondirectory file)))
		    (message "Query %s in %s..." word name)
		    ;; 本文を検索
		    (if (or (= (length page) 0)
			    (string-match page name))
			(if (= (length word) 0)
			    (setq matched-pages (append `((,name . ,domain)) matched-pages))
			  (if (link-memo-search-text domain name word t)
			      (setq matched-pages (append `((,name . ,domain)) matched-pages))
			    )))))
	      (setq files (cdr files))))
	  (setq dirs (cdr dirs)))))
    (if matched-pages
	(progn
	  (link-memo-list-pages "*QueryResult*" (concat "Query : " page ", " word) matched-pages)
	  (message "Query %s...done" word))
      (error "Query %s...not found" word))))

(defun link-memo-list-pages (buffer-name title pagenames)
  "一覧バッファ"
  ;; 出力用のバッファを作って。
  (set-window-buffer (selected-window) (set-buffer (get-buffer-create buffer-name)))
  (setq buffer-read-only nil)
  (use-local-map link-memo-page-list-map)
  (erase-buffer)
  ;; そこに吐き出す
  ;; ヘッダ部
  (insert title)
  (newline)
  ;; データ部
  (let ((names (sort pagenames
		     #'(lambda (src dest)
			 (string< (car src) (car dest)))
		     )))
    (while names
      (let ((bp)
	    (ep)
	    (name (caar names))
	    (domain (cdar names)))
	(setq bp (point))
	(insert name)
	(setq ep (point))
	(link-memo-make-link-ex bp ep name domain)
	(end-of-line)
	(insert " ... ")
	(insert domain)
	(newline)
	)
      (setq names (cdr names))))
  (goto-char (point-min))
  (link-memo-next-link)
  (setq buffer-read-only t))

(defun link-memo-make-link-ex (bp ep name domain)
  "リンクを張る."
  (add-text-properties bp ep
		       `( ;; face
			 ;; underline
			 ;; (foreground-color . "blue")
			 mouse-face
			 (background-color . "#c0c0ff")
			 link-memo-link
			 ,name
			 link-memo-domain
			 ,domain)))

(defun link-memo-index ()
  "登録されているページの一覧を表示する。"
  (interactive)
  (let ((pagenames)
	(matched-pages nil)
	(file))
    (save-excursion
      (save-restriction
	(message "List up...")
	(setq pagenames (reverse link-memo-pagenames))
	(link-memo-list-pages-for-index "*IndexPage*" (format "IndexPage (%d pages)" (length pagenames)) pagenames)
	(message "List up...done")))))

(defun link-memo-list-pages-for-index (buffer-name title pagenames)
  "一覧バッファ"
  ;; 出力用のバッファを作って。
  (set-window-buffer (selected-window) (set-buffer (get-buffer-create buffer-name)))
  (setq buffer-read-only nil)
  (use-local-map link-memo-page-list-map)
  (erase-buffer)
  ;; そこに吐き出す
  ;; ヘッダ部
  (insert title)
  (newline)
  ;; データ部
  (let ((names (sort pagenames
		     'string<)))
    (while names
      (let ((bp)
	    (ep)
	    (name (car names)))
	(setq bp (point))
	(insert name)
	(setq ep (point))
	(end-of-line)
	(newline)
	(link-memo-make-link bp ep name)
	)
      (setq names (cdr names))))
  (goto-char (point-min))
  (link-memo-next-link)
  (setq buffer-read-only t))

(defun link-memo-find-file ()
  "find-fileっつーかリストからの選択。
存在しないページ名が指定された場合は、新規ページ作成とみなす。"
  (interactive)
  (let ((pagenames)
	(page)
	(choicies)
	(completion-ignore-case t)) ;; TODO: システムのcaseを入れたほうがいいかも?
    (setq pagenames link-memo-pagenames)
    (while pagenames
      (setq choicies
	    (append (list (list (car pagenames)))
		    choicies))
      (setq pagenames (cdr pagenames)))
    (setq page
	  (completing-read "link-memo-find-file: " choicies))
    (if (and (not (null page))
	     (not (string= page "")))
	(find-file (link-memo-expand-file-name page)))))

(defun link-memo-view-file ()
  "view-fileっつーかリストからの選択。
存在しないページ名の指定は不可。"
  (interactive)
  (let ((pagenames)
	(page)
	(choicies)
	(completion-ignore-case t)) ;; TODO: システムのcaseを入れたほうがいいかも?
    (setq pagenames link-memo-pagenames)
    (while pagenames
      (setq choicies
	    (append (list (list (car pagenames)))
		    choicies))
      (setq pagenames (cdr pagenames)))
    (setq page
	  (completing-read "link-memo-view-file: " choicies nil t)) ; viewなので存在しないファイルは許可しない
    (if page
	(view-file (link-memo-expand-file-name page)))))

(defun link-memo-next-link ()
  "次のリンクを探す。"
  (interactive)
  (let (pt)
    ;; 既にリンクの上にポイントがある場合は、いったんリンクの上から抜ける。
    (if (get-text-property (point) 'link-memo-link)
	(progn
	  (setq pt (next-single-property-change (point) 'link-memo-link))
	  (if pt (goto-char pt))))
    (setq pt (next-single-property-change (point) 'link-memo-link))
    (if pt (progn ;; (message "current link is \"%s\"." (get-text-property pt 'link-memo-link))
	     (goto-char pt)))))

(defun link-memo-previous-link ()
  "前のリンクを探す。"
  (interactive)
  (let (pt)
    ;; 既にリンクの上にポイントがある場合は、いったんリンクの上から抜ける。
    (if (get-text-property (point) 'link-memo-link)
	(progn
	  (setq pt (previous-single-property-change (point) 'link-memo-link))
	  (if pt (goto-char pt))))
    (setq pt (previous-single-property-change (point) 'link-memo-link))
    (if pt (progn ;; (message "current link is \"%s\"." (get-text-property pt 'link-memo-link))
	     (goto-char pt)))))

(defun link-memo-expand-file-name (page &optional domain)
  "pageをフルパスに展開。
dirは省略可能。指定されたならそこのディレクトリ固定。
複数のディレクトリにファイルが存在する場合はどれにするか聞く。
`link-memo-extension'nがnilでなければ拡張子付加する。"
  (if domain
      (link-memo-expand-file-name-internal page domain)
    (let ((dirs link-memo-dir)
	  (dir)
	  (domain)
	  (choicies nil))
      (while dirs
	(setq domain (caar dirs))
	(setq dir (cdar dirs))
	(if (file-readable-p (link-memo-expand-file-name-internal page domain))
	    (progn
	      (add-to-list 'choicies `(,domain . ,dir))))
	(setq dirs (cdr dirs)))
      (setq domain
	    (if (= (length choicies) 0)
		;; マッチしない場合はドメインを聞く
		(completing-read (format "Choose dir (default:%s): " (caar link-memo-dir))
				 link-memo-dir nil t nil nil (caar link-memo-dir))
	      (if (= (length choicies) 1)
		  (caar choicies) ; 直
		(let ((completion-ignore-case t))
		  (setq choicies (reverse choicies))
		  (completing-read (format "Choose dir (default:%s): " (caar choicies))
				   choicies nil t nil nil (caar choicies))
		  ))))
      (link-memo-expand-file-name-internal page domain))))

(defun link-memo-expand-file-name-internal (page domain)
  "内部向け
pageをフルパスに展開。
複数のディレクトリにファイルが存在する場合はどれにするか聞く。
その際 `link-memo-extension-list' の内容に応じて拡張子付加する。
nil の場合は付加しない。
要素が 1つの場合はその内容を付加する。
複数存在する場合は問い合わせる。"
  (let ((ext (cdr (assoc domain link-memo-extension-alist)))
	(dir (cdr (assoc domain link-memo-dir))))
    (if ext
	(concat (expand-file-name dir)
		page "." ext)
      (concat (expand-file-name dir)
	      page))))

(defun link-memo-view-random-file ()
  "ランダムで開く。
たまには、作りっぱなしのページも読まないとね。
という話。"
  (interactive)
  (progn
    (random t)
    (view-file
     (link-memo-expand-file-name (nth (random (length link-memo-pagenames))
				      link-memo-pagenames)))))

(defun link-memo-refresh-pagename-table ()
  "テーブルのリフレッシュ。"
  (interactive)
  (link-memo-make-pagename-table))

(defun link-memo-pagenames-regexp ()
  "`link-memo-pagenames'をregexp-optした文字列を返す。"
  (if (or (null link-memo-pagenames-regexp-cache-build-time)
	  (string< (format "%s%06d" ;; TODO: %06d と %08d どっちが正しいのか... 要検討
			   (format-time-string "%Y%m%d%H%M%S" link-memo-pagenames-regexp-cache-build-time)
			   (nth 2 link-memo-pagenames-regexp-cache-build-time))
		   (format "%s%06d" ;; TODO: %06d と %08d どっちが正しいのか... 要検討
			   (format-time-string "%Y%m%d%H%M%S" link-memo-pagenames-modify-time)
			   (nth 2 link-memo-pagenames-modify-time))))
      (let ((pagenames (link-memo-pagenames-upcase link-memo-pagenames)))
	(message "build link-memo-pagenames-regexp-cache...")
	(setq link-memo-pagenames-regexp-cache
	      (let ((max-specpdl-size (* 1024 4)))
		(regexp-opt pagenames)))
	(setq link-memo-pagenames-regexp-cache-build-time
	      (current-time))
	(message "build link-memo-pagenames-regexp-cache...done")))
  link-memo-pagenames-regexp-cache)

(defun link-memo-pagenames-upcase (pages)
  "リストのメンバを大文字にした新しいリストを返す。"
  (let ((upcase-pages (list)))
    (while pages
      (setq upcase-pages (nconc upcase-pages
				(list (upcase (car pages)))
				))
      (setq pages (cdr pages)))
    upcase-pages))

;; ロード時に実行する処理

(make-variable-buffer-local 'link-memo-mode)

(link-memo-make-pagename-table)

;; 開いた(find-file した)ファイルが link-memo-dir 内のファイルなら、
;; 自動的に link-memo-mode を有効にする。
;; TODO: 複数回loadされたときの保護をしないと... そのためにはlambdaをやめて名前あり関数にして、hookに存在しない場合のみ追加するようにするのが正解か?
(add-hook 'find-file-hooks
	  '(lambda ()
	     (let ((dirs link-memo-dir)
		   (dir))
	       (while dirs
		 (setq dir (cdar dirs))
		 (if (string= (expand-file-name (file-name-directory buffer-file-name))
			      (expand-file-name dir))
		     (link-memo-mode t))
		 (setq dirs (cdr dirs))))))

;; 保存したファイルが link-memo-dir 内のファイルなら、
;; 自動的に link-memo-pagenames に追加する。
;; TODO: 複数回loadされたときの保護をしないと... そのためにはlambdaをやめて名前あり関数にして、hookに存在しない場合のみ追加するようにするのが正解か?
(add-hook 'after-save-hook
	  '(lambda ()
	     (let ((dirs link-memo-dir)
		   (dir))
	       (while dirs
		 (setq dir (cdar dirs))
		 (if (string= (expand-file-name (file-name-directory buffer-file-name))
			      (expand-file-name dir))
		     (link-memo-add-pagename (file-name-sans-extension
					      (file-name-nondirectory buffer-file-name)) t))
		 (setq dirs (cdr dirs))))))

;; キーマップの処理
;; TODO: (if link-memo-mode-map ...)で複数回loadされたときの保護をしないと...
;; TODO: overlayの`local-map'属性使ったほうがスマートなものもある。
(setq link-memo-mode-map (make-sparse-keymap))
(define-key link-memo-mode-map "\M-n" 'link-memo-next-link)
(define-key link-memo-mode-map "\M-p" 'link-memo-previous-link)
(define-key link-memo-mode-map "\M-j" 'link-memo-jump-to-link)
(define-key link-memo-mode-map "\M-\C-o" 'link-memo-jump-to-link-other-frame)
(define-key link-memo-mode-map "\M-o" 'link-memo-jump-to-link-other-window)
(define-key link-memo-mode-map "\C-c\C-k\C-l" 'link-memo-highlight-buffer)
(define-key link-memo-mode-map "\C-c\C-k\C-t" 'link-memo-search-this-page)

(setq link-memo-page-list-map (make-sparse-keymap))
(define-key link-memo-page-list-map "\M-j" 'link-memo-jump-to-link)
(define-key link-memo-page-list-map "\M-o" 'link-memo-jump-to-link-other-frame)
(define-key link-memo-page-list-map "\C-j" 'link-memo-jump-to-link)
(define-key link-memo-page-list-map "\C-m" 'link-memo-jump-to-link)
(define-key link-memo-page-list-map [return] 'link-memo-jump-to-link)
(define-key link-memo-page-list-map [mouse-2] 'link-memo-jump-to-link)
(define-key link-memo-page-list-map [right] 'link-memo-next-link)
(define-key link-memo-page-list-map [down] 'link-memo-next-link)
(define-key link-memo-page-list-map [left] 'link-memo-previous-link)
(define-key link-memo-page-list-map [up] 'link-memo-previous-link)
(define-key link-memo-page-list-map "e" 'link-memo-jump-to-link)
(define-key link-memo-page-list-map "f" 'link-memo-jump-to-link)
(define-key link-memo-page-list-map "n" 'link-memo-next-link)
(define-key link-memo-page-list-map "o" 'link-memo-jump-to-link-other-window)
(define-key link-memo-page-list-map "p" 'link-memo-previous-link)
(define-key link-memo-page-list-map "q" 'quit-window)
(define-key link-memo-page-list-map "v" 'link-memo-jump-to-link-view)

(or (assq 'link-memo-mode minor-mode-map-alist)
    (setq minor-mode-map-alist
          (cons (cons 'link-memo-mode link-memo-mode-map) minor-mode-map-alist)))

;;; link-memo.el ends here
