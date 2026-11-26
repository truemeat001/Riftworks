# P07 开发 checkpoint 说明
此开发分支包含冻结代码、工具、音效生成参数/清单、全部验收记录及规范。继承 P05 文本 checkpoint，Git LFS 新资产仍需真实上传对象及 clone hydration；未上传悬空LFS指针，也未绕开既有LFS策略。
P07 原创音频可根据 scripts/make_audio_p07.py 在完整工程内重建（48kHz/24-bit mother + 16-bit runtime）；不要将远端旧 P04 二进制与 P05/P07 清单组合，**远端文本分支不等于完整可构建交付**。完整工程另存私有源码归档；验证使用本地完整工程。GitHub CLI 正常登录和LFS可用性确认后再提交实际新增二进制。
