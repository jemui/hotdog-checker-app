//
//  ViewController.swift
//  HotdogCheckerApp
//
//  Created by Jeanette on 2/25/25.
//

import UIKit
import CoreML
import Vision
import PhotosUI

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    private var imageContinuation: CheckedContinuation <UIImage?, Never>?
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = false
    }

  
    
    @IBAction func cameraTapped(_ sender: UIBarButtonItem) {
        
        present(imagePicker, animated: true, completion: nil)
        
    }
    
    @IBAction func photoLibraryTapped(_ sender: UIBarButtonItem) {
        Task {
            if let image = await presentPhotoPicker() {
                imageView.image = image
                detect(image: image)
            }
        }
    }
    
    private func presentPhotoPicker() async -> UIImage? {
        return await withCheckedContinuation { continuation in
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true)
            
            self.imageContinuation = continuation
            
        }
    }
}

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            imageContinuation?.resume(returning: nil)
            imageContinuation = nil
            return
        }
        
        Task {
            let image = await loadImage(from: provider)
            imageContinuation?.resume(returning: image)
            imageContinuation = nil
            
        }
    }
    
    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, error in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }
    
    private func detect(image: UIImage) {
        
        guard let ciimage = CIImage(image: image) else {
            print("[d] couldnt convert to ciimage")
            return
        }
        
        let config = MLModelConfiguration()
        guard let model = try? VNCoreMLModel(for: Inceptionv3(configuration: config).model) else {
            print("[d] loading core ml model failed<##>")
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNClassificationObservation] else {
                print("[d] model failed to process image<##>")
                return
            }
            
            guard let firstResult = results.first else {
                print("[d] no results found")
                return
            }
            
            if(firstResult.identifier.contains("hotdog")) {
                self.navigationItem.title = "Hotdog!"
            } else {
                self.navigationItem.title = "Not Hotdog!"
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: ciimage)
        
        do {
            try handler.perform([request])
        }
        catch {
            print(error)
        }
      
    }
}

extension ViewController: UIImagePickerControllerDelegate {
    
      func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
          
          if let userPickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
              imageView.image = userPickedImage
              
              detect(image: userPickedImage)
          }
          imagePicker.dismiss(animated: true)
      }
      
}

extension ViewController: UINavigationControllerDelegate {
    
}
