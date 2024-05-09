# XcodeRootDebug
 Xcode以root权限调试app

注意 debugserver一定要从手机上的/Developer/usr/bin/debugserver这个路径复制到电脑上

在使用ldid -Sent.xml debugserverw签名:

ent.xml内容如下:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.springboard.debugapplications</key>
	<true/>
	<key>com.apple.backboardd.launchapplications</key>
	<true/>
	<key>com.apple.backboardd.debugapplications</key>
	<true/>
	<key>com.apple.frontboard.launchapplications</key>
	<true/>
	<key>com.apple.frontboard.debugapplications</key>
	<true/>
	<key>com.apple.private.logging.diagnostic</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.private.memorystatus</key>
	<true/>
	<key>com.apple.private.cs.debugger</key>
	<true/>
	<key>com.apple.private.thread-set-state</key>
	<true/>
	<key>com.apple.private.security.no-container</key>
	<true/>
	<key>com.apple.private.skip-library-validation</key>
	<true/>
	<key>com.apple.system-task-ports</key>
	<true/>
	<key>get-task-allow</key>
	<true/>
	<key>platform-application</key>
	<true/>
	<key>run-unsigned-code</key>
	<true/>
	<key>task_for_pid-allow</key>
	<true/>
</dict>
</plist>
```

 然后再放回手机上/usr/bin/debugserver或者/var/jb/bin/debugserver

```
chmod +x debugserver
```

然后安装该项目插件，xcode则可以正常使用了
