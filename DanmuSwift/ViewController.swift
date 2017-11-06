//
//  ViewController.swift
//  DanmuSwift
//
//  Created by 孙伟伟 on 2017/11/1.
//  Copyright © 2017年 孙伟伟. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var danmuMange : DanmuManage?;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.danmuMange = DanmuManage.init(frame: CGRect(x: 0, y: 0, width: AppWidth, height: 300));
        self.danmuMange?.registerClass(cellClass: DanmuView.layerClass ,identifier :"cell");
        self.view.addSubview(self.danmuMange!);
    }
}

extension ViewController {
    
    @IBAction func StartAction(_ sender: Any) {
        print(sender);
        self.danmuMange?.play();
    }

    @IBAction func PauseAction(_ sender: Any) {
        print(sender);
        self.danmuMange?.pause();
    }
    
    @IBAction func StopAction(_ sender: Any) {
        print(sender);
        self.danmuMange?.stop();
    }
    
    @IBAction func SendDanmu(_ sender: Any) {
//        print(sender);
        let c : Int = Int(arc4random_uniform(13));
        let contentArray = ["swdedf",
                            "我是谁谁谁谁","我是","我谁","我","谁",
                            "我是谁谁我是谁谁谁谁我是谁谁谁谁我是谁谁谁谁我是谁谁谁谁谁谁",
                            "测试数我的你的大家的",
                            "6789045",
                            "ghjkliouipohjlk",
                            "ghjklijlqwdqefrgtouipohjlk",
                            "wdef123456782345678io",
                            "uej3kqefdvsjnlqeofadilqeadjpzck;"];
        
         let width = DanmuDefine.shared.getTextCGSize(contentArray[c], UIFont.systemFont(ofSize: 14)).width + 1.0;
        //生产弹幕，先从缓存中取danmu。
        var danmuView : DanmuView? = self.danmaForDequeueReusable(contentArray[c]);
        if (danmuView == nil) {
            //取不到，则创建新弹幕
            danmuView = DanmuView.init(frame: CGRect(x: 0, y: 0, width: width, height: 25));
            danmuView?.px = AppWidth;
            danmuView?.py = 0;
            danmuView?.remainingTime = 0;
            danmuView?.initWithContent(content: contentArray[c]);
        }
        self.danmuMange?.sendDanmu(danmuView);
    }
    
    func danmaForDequeueReusable(_ danmakuStr : String) -> DanmuView? {
        let danmuView : DanmuView? = self.danmuMange?.dequeueReusableDanmaWithIdentifier(danmakuStr);
        if danmuView == nil {
            return nil;
        }
        
        let width = DanmuDefine.shared.getTextCGSize(danmakuStr, UIFont.systemFont(ofSize: 14)).width + 1.0;
//        let danmuView : DanmuView = DanmuView.init(frame: CGRect(x: 0, y: 0, width: width, height: 25));
        danmuView?.px = AppWidth;
        danmuView?.py = 0;
        danmuView?.remainingTime = 0;
        danmuView?.size = CGSize(width: width, height: 25);
        danmuView?.setDanmuUI(danmakuStr);
        return danmuView;
    }
    
    override var prefersStatusBarHidden: Bool{
        return true;
    }
}


