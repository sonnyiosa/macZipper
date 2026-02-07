
We are building a modern macOS zip file extractor with the features.

# 1. Technology Stack
Recommended Approach: Native Swift + SwiftUI

Language: Swift 5.9+
UI Framework: SwiftUI (modern, declarative UI)
Zip Handling: ZIPFoundation 
Minimum Target: macOS 13.0
Project setup: XcodeGen (https://github.com/yonaskolb/XcodeGen) 
 + Configured at: @project.yml


# 2. Feature requirements

- Zip Contents Preview: Two-pane interface (folder tree in the left, and file list on the right)
- Select/Unselect Files
- Extract Functionality
- Double-Click to Open
- [ ] Extract selected files should ask to chooes destination folder
- [ ] "Move to" with selected files didnt work
- [ ] Compose new zip 
- [ ] More archive types support: gzip, gz, tar
- [ ] Search in zip
- [ ] Open folder in FileListView should navigate to it 

