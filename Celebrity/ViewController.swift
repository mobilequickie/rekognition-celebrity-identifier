//
//  ViewController.swift
//  Celebrity
//
//  Created by Hills, Dennis on 5/6/19.
//  Copyright © 2019 Hills, Dennis. All rights reserved.
//
import UIKit
import AVFoundation
import SafariServices
import AWSRekognition

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SFSafariViewControllerDelegate {
    
    @IBOutlet weak var CelebrityImageView: UIImageView!
    @IBOutlet weak var CameraButton: UIButton!
    @IBOutlet weak var PhotoLibraryButton: UIButton!
    
    var infoLinksMap: [Int:String] = [1000:""]
    var rekognitionObject:AWSRekognition?
    
    //var vSpinner : UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        if let celebImage = CelebrityImageView.image?.jpegData(compressionQuality: 0.8) {
            sendImageToRekognition(celebImageData: celebImage)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Button Actions
    @IBAction func CameraOpen(_ sender: Any) {
        
        if UIImagePickerController.isSourceTypeAvailable(.camera){
            if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
                let pickerController = UIImagePickerController()
                pickerController.delegate = self
                pickerController.sourceType = .camera
                pickerController.cameraCaptureMode = .photo
                self.present(pickerController, animated: true)
            } else {
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                    if granted {
                        let pickerController = UIImagePickerController()
                        pickerController.delegate = self
                        pickerController.sourceType = .camera
                        pickerController.cameraCaptureMode = .photo
                        self.present(pickerController, animated: true)
                    } else {
                        print("access denied to use camera")
                    }
                })
            }
        } else {
            print("This device has no camera")
        }
    }
    
    @IBAction func PhotoLibraryOpen(_ sender: Any) {
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.sourceType = .savedPhotosAlbum
        present(pickerController, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        // Set the selected image as a UIImage
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
                print("No image found")
            return
        }
        // Display the selected image in the celebrity image view
        CelebrityImageView.image = image
        
        // Convert selected UIImage to JPEG before sending to Rekognition
        if let celebImage = image.jpegData(compressionQuality: 0.8) {
                sendImageToRekognition(celebImageData: celebImage)
        }
    }
    
    /*
     This is the meat of the app for calling Amazon Rekognition directly.
     Returns: An array of celebrities recognized in the input jpeg image.
     More info, see https://docs.aws.amazon.com/rekognition/latest/dg/celebrities.html.
     The RecognizeCelebrities API returns the 100 largest faces in the image.
     Lookout Thanos!
    */
    func sendImageToRekognition(celebImageData: Data){
        
        self.showSpinner(onView: self.view)
        
        // Delete older celebrity labels names or buttons
        DispatchQueue.main.async {
            [weak self] in
            for subView in (self?.CelebrityImageView.subviews)! {
                subView.removeFromSuperview()
            }
        }
        
        rekognitionObject = AWSRekognition.default()
        let celebImageAWS = AWSRekognitionImage()
        celebImageAWS?.bytes = celebImageData
        let celebRequest = AWSRekognitionRecognizeCelebritiesRequest()
        celebRequest?.image = celebImageAWS
        
        rekognitionObject?.recognizeCelebrities(celebRequest!){
            (result, error) in
            
            if error != nil{
                print(error!)
                self.removeSpinner()
                return
            }
            
            self.removeSpinner()
            
            // 1. First we check if there are any celebrities in the response
            if ((result!.celebrityFaces?.count)! > 0){
                print("Found [\(String(describing: result!.celebrityFaces?.count))] celebrities.")
                // 2. Iterate through found celebrities
                for (index, celebFace) in result!.celebrityFaces!.enumerated(){
                    
                    // Check the confidence value returned by the API for each celebirty identified. Here we are deciding that if the confidence is 50 or less % then don't count as a celebrity.
                    if(celebFace.matchConfidence!.intValue > 50){
                        
                        // We are confident this is celebrity. Lets point them out in the image using the main thread
                        DispatchQueue.main.async {
                            [weak self] in
                            
                            // Create an instance of Celebrity.
                            let celebrityInImage = Celebrity()
                            
                            celebrityInImage.scene = (self?.CelebrityImageView)!
                            
                            // Get the coordinates for where this celebrity face is in the image and pass them to the Celebrity instance
                            celebrityInImage.boundingBox = ["height":celebFace.face?.boundingBox?.height, "left":celebFace.face?.boundingBox?.left, "top":celebFace.face?.boundingBox?.top, "width":celebFace.face?.boundingBox?.width] as? [String : CGFloat]
                            
                            // Get the celebrity name and pass it along
                            celebrityInImage.name = celebFace.name!
                            // Get the first url returned by the API for this celebrity. This is going to be an IMDb profile link
                            if (celebFace.urls!.count > 0){
                                celebrityInImage.infoLink = celebFace.urls![0]
                            }
                            // If there are no links direct them to IMDB search page
                            else {
                                celebrityInImage.infoLink = "https://www.imdb.com/search/name-text?bio="+celebrityInImage.name
                            }
                            // Update the celebrity links map that we will use next to create buttons
                            self?.infoLinksMap[index] = "https://"+celebFace.urls![0]
                            
                            // Create a button that will take users to the IMDb link when tapped
                            let infoButton:UIButton = celebrityInImage.createInfoButton()
                            infoButton.tag = index
                            infoButton.addTarget(self, action: #selector(self?.handleTap), for: UIControl.Event.touchUpInside)
                            self?.CelebrityImageView.addSubview(infoButton)
                        }
                    }
                }
            }
            // No celebrities found but did we identifies any faces?
            else if ((result!.unrecognizedFaces?.count)! > 0){
                print("Found [\(String(describing: result!.unrecognizedFaces?.count))] faces not identified as celebrities")
            }
            else{
                print("No human faces found in this image.")
            }
        }
    }
    
    // Handles the launching of IMDB in Safari with the celebrity profile
    @objc func handleTap(sender:UIButton){
        print("tap recognized")
        let celebURL = URL(string: self.infoLinksMap[sender.tag]!)
        let safariController = SFSafariViewController(url: celebURL!)
        safariController.delegate = self
        self.present(safariController, animated:true)
    }
}

// Simple spinner to show activity
// 
var vSpinner : UIView?

extension UIViewController {
    func showSpinner(onView : UIView) {
        let spinnerView = UIView.init(frame: onView.bounds)
        spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        let ai = UIActivityIndicatorView.init(style: .whiteLarge)
        ai.startAnimating()
        ai.center = spinnerView.center
        
        DispatchQueue.main.async {
            spinnerView.addSubview(ai)
            onView.addSubview(spinnerView)
        }
        
        vSpinner = spinnerView
    }
    
    func removeSpinner() {
        DispatchQueue.main.async {
            vSpinner?.removeFromSuperview()
            vSpinner = nil
        }
    }
}


