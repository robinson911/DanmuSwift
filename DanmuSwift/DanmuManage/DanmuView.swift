//
//  DanmuView.swift
//  DanmuSwift
//
//  Created by 孙伟伟 on 2017/11/1.
//  Copyright © 2017年 孙伟伟. All rights reserved.
//

import Foundation
import UIKit

class DanmuView : UIView {
    
    var px : CGFloat?;
    var py : CGFloat?;
    var size : CGSize?;
    var reuseIdentifier : NSString?;
    var ljBulletLabel : UILabel?;
    
    //轨道 trajectory, 默认轨道： -1
    var yIdx : NSInteger?;
    //弹幕运行时间
    var remainingTime : Float?;
    
    override init(frame: CGRect) {
        super.init(frame: frame);
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initWithContent(content : String){
        self.setDanmuUI(content);
    }
    
    func initWithReuseIdentifier(_ reuseIdentifier : String){
        self.reuseIdentifier = reuseIdentifier as NSString;
        self.setDanmuUI("");
    }
    
    func setDanmuUI(_ str : String) {
        self.isUserInteractionEnabled = true;
        
        let width = DanmuDefine.shared.getTextCGSize(str, UIFont.systemFont(ofSize: 14)).width + 1.0;
        
        self.ljBulletLabel = UILabel.init();
        self.ljBulletLabel?.backgroundColor = UIColor.orange;
        self.ljBulletLabel?.layer.cornerRadius = 2;
        self.ljBulletLabel?.layer.borderWidth = 1;
        self.ljBulletLabel?.frame = CGRect(x: 0, y: 0, width:Int(width), height: CellHeight);
        self.ljBulletLabel?.font = UIFont.systemFont(ofSize: 14);
        self.ljBulletLabel?.text = str;
        self.addSubview(self.ljBulletLabel!);
    }
}
