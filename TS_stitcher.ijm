//description of this macro:
//This macro will stitch PPL, XPL and FLO images taken with a microscope. You will need a grid of pictures, with 20% overlap between them.
//It will keep your pictures aligned during the process, and subtract the background from PPL images
//in order to run this macro, you will need a root folder (named after your sample), and inside this folder there should be the background image, and three other folders: PPL, XPL and FLO
//each of these folders should have its respective images. The name of the image files does not matter, as long as they are IN ORDER
//Originally, the macro will not save any of the intermediary images (PPL subtracted, for example), but will only save the final, stitched images.
//This can be changed by selecting the appropriate menu checkbox

Dialog.create("Message");
	Dialog.addMessage("To use this Macro you need your pictures sorted into 3 folders: PPL, XPL and FLO. No renaming necessary. \n"+
	"These 3 folders should be inside a root folder, along with the background image, named 'background.tif' \n"+
	"This macro currently supports A GRID OF UP TO 99 PICTURES"+
	"Select root folder (FLO, PPL, XPL and background should be INSIDE this folder");
	Dialog.show();
folder=getDirectory("Select root folder (FLO, PPL, XPL and background should be INSIDE this folder");
list = getFileList(folder);

if (!File.exists(folder + "FLO") | !File.exists(folder + "XPL") | !File.exists(folder + "PPL"))
      exit("This directory does not seem right. It must contain the folders FLO, PPL and XPL");

Dialog.create("Enter information about thin section images matrix");
	Dialog.addNumber("Matrix x (how many columns?)", 5);
	Dialog.addNumber("Matrix y (how many rows?)", 4);
	Dialog.addCheckbox("Save inter-step files? (ONLY RECOMMENDED FOR DEBUGGING)", false);
	Dialog.addCheckbox("Threshold background image? Makes for brighter final PPL", true);
	Dialog.addMessage("The values below are suggested for BX60 microscope");
	Dialog.addNumber("Lower threshold for background", 37);
	Dialog.addNumber("Upper threshold for background", 292);
	Dialog.show();
	matrix_x = Dialog.getNumber();
	matrix_y = Dialog.getNumber();
	save_files = Dialog.getCheckbox();
	check_threshold = Dialog.getCheckbox();
	lower_threshold = Dialog.getNumber();
	upper_threshold = Dialog.getNumber();

n_images = (matrix_x*matrix_y);

if (File.exists(folder + "final"))
      exit("The 'final' folder already exists! Check to see if no files in there! \n This macro will only run if no 'final' folder exists.");
File.makeDirectory(folder + "final");
if (save_files){

	File.makeDirectory(folder + "PPL_subtracted");
	File.makeDirectory(folder + "fused");
	File.makeDirectory(folder + "stack_rgb");
	File.makeDirectory(folder + "XPL_renamed");
	File.makeDirectory(folder + "FLO_renamed");
	
	//removing background and saving into PPL_subtracted folder
	open(folder + "background.tif"); 
	run("8-bit");
	if (check_threshold){
		run("Window/Level...");
		setMinAndMax(lower_threshold, upper_threshold);
	}
	run("RGB Color");
	run("Image Sequence...", "open=" + folder + "PPL/PPL_001.tif number=" +n_images+" sort");
	run("Calculator Plus", "i1=PPL i2=background.tif operation=[Divide: i2 = (i1/i2) x k1 + k2] k1=128 k2=0 create");
	run("Image Sequence... ", "format=TIFF name=[] start=1 digits=3 save=" + folder + "PPL_subtracted/");
	close();
	close();
	selectWindow("background.tif");
	close();
	run("Close All");
	
	//renaming all picture files
	//XPL
	run("Image Sequence...", "open=" + folder + "XPL/XPL_001.tif number=" + n_images +" sort");
	run("Image Sequence... ", "format=TIFF name=[XPL_] start=1 digits=3 save=" + folder + "XPL_renamed/");
	run("Close All");
	
	//FLO
	run("Image Sequence...", "open=" + folder + "FLO/FLO_001.tif number=" + n_images +" sort");
	run("Image Sequence... ", "format=TIFF name=[FLO_] start=1 digits=3 save=" + folder + "FLO_renamed/");
	run("Close All");
	
	
	//joining into stack
	if (n_images>0) {
	
		for (i=1; i<10; i++){
			open("" + folder + "PPL_subtracted/00" +i+ ".tif");
			//run("Split Channels");
			open("" + folder + "FLO_renamed/FLO_00" +i+ ".tif");
			//run("Split Channels");
			open("" + folder + "XPL_renamed/XPL_00" +i+ ".tif"); //uncomment this if you have XPL
			//run("Split Channels");
			run("Images to Stack", "name=Stack0" +i+ " title=[] use");
			saveAs("Tiff", "" + folder + "stack_rgb/stack00" +i+ ".tif");
			close();
		}
		
		//update to the number of images your sample has in total (is less than 100)
		if (n_images>9) {
	
			for (i=10; i<=n_images; i++){
				open("" + folder + "PPL_subtracted/0" +i+ ".tif");
				//run("Split Channels");
				open("" + folder + "FLO_renamed/FLO_0" +i+ ".tif");
				//run("Split Channels");
				open("" + folder + "XPL_renamed/XPL_0" +i+ ".tif");
				//run("Split Channels");
				run("Images to Stack", "name=Stack" +i+ " title=[] use");
				saveAs("Tiff", "" + folder + "stack_rgb/stack0" +i+ ".tif");
				close();
			}
		}
	}
	
	//stitching
	run("Grid/Collection stitching",
	"type=[Grid: snake by rows] order=[Right & Down                ] "+
	"grid_size_x="+matrix_x+" grid_size_y="+matrix_y+" "+
	"tile_overlap=20 "+
	"first_file_index_i=1 "+
	"directory="+ folder+"stack_rgb "+
	"file_names=stack{iii}.tif "+
	"output_textfile_name=TileConfiguration.txt "+
	"fusion_method=[Linear Blending] "+
	"regression_threshold=0.30 "+
	"max/avg_displacement_threshold=2.50 "+
	"absolute_displacement_threshold=3.50 "+
	"compute_overlap "+
	"computation_parameters=[Save computation time (but use more RAM)] "+
	"image_output=[Fuse and display]");
	
	//splitting into channels and saving
	run("Stack to Images");
	
	for (i = 1; i <=9; i++){ 
		selectWindow("Fused-000" +i);
		run("Grays");
		run("8-bit");
		saveAs("Tiff", folder+"fused/Fused0" +i+ ".tif");
	}
	
	run("Merge Channels...", "c1=Fused01.tif c2=Fused02.tif c3=Fused03.tif create");
	run("RGB Color");
	saveAs("Tiff", folder+"final/PPL.tif");
	close();
	close();
	run("Merge Channels...", "c1=Fused04.tif c2=Fused05.tif c3=Fused06.tif create");
	run("RGB Color");
	saveAs("Tiff", folder+"final/FLO.tif");
	close();
	close();
	run("Merge Channels...", "c1=Fused07.tif c2=Fused08.tif c3=Fused09.tif create");
	run("RGB Color");
	saveAs("Tiff", folder+"final/XPL.tif");
	close();
	close();
	print("Command successfully finished!");
}
else{
	// Get path to temp directory
	tmp = getDirectory("temp");
	if (tmp=="")
	  exit("No temp directory available");
	
	// Create a directory in temp
	temp_folder = tmp+"my-temp-dir"+File.separator;
	File.makeDirectory(temp_folder);
	if (!File.exists(temp_folder))
	  exit("Unable to create directory");
	print("");
	print(temp_folder);
	
	//removing background and saving into PPL_subtracted folder
	print("removing background from PPL images");
	open(folder + "background.tif"); 
	run("8-bit");
	if (check_threshold){
		run("Window/Level...");
		setMinAndMax(lower_threshold, upper_threshold);
	}
	run("RGB Color");
	run("Image Sequence...", "open=" + folder + "PPL/PPL_001.tif number=" +n_images+" sort"); //the name of files does not matter for the image sequence
	run("Calculator Plus", "i1=PPL i2=background.tif operation=[Divide: i2 = (i1/i2) x k1 + k2] k1=128 k2=0 create");
	run("Image Sequence... ", "format=TIFF name=[PPL_] start=1 digits=3 save="+temp_folder);
	close();
	close();
	selectWindow("background.tif");
	close();
	run("Close All");
	
	//renaming all picture files
	//XPL
	print("renaming XPL images");
	run("Image Sequence...", "open=" + folder + "XPL/XPL_001.tif number=" + n_images +" sort");
	run("Image Sequence... ", "format=TIFF name=[XPL_] start=1 digits=3 save="+temp_folder); //it renames the files as they are saved (open w/ whatever name > save in order, rneamed)
	run("Close All");
	
	//FLO
	print("renaming FLO images");
	run("Image Sequence...", "open=" + folder + "FLO/FLO_001.tif number=" + n_images +" sort");
	run("Image Sequence... ", "format=TIFF name=[FLO_] start=1 digits=3 save="+temp_folder);
	run("Close All");
	
	
	//joining into stack
	print("creating a stack of images from PPL, XPL and FLO");
	if (n_images>0) {
	
		for (i=1; i<10; i++){
			open(temp_folder+"PPL_00" +i+ ".tif");
			//run("Split Channels");
			open(temp_folder+"FLO_00" +i+ ".tif");
			//run("Split Channels");
			open(temp_folder+"XPL_00" +i+ ".tif");
			//run("Split Channels");
			run("Images to Stack", "name=Stack0" +i+ " title=[] use");
			saveAs("Tiff", temp_folder+"stack00" +i+ ".tif");
			close();
		}
		
		//currently this macro only supports a grid of up to 99 pictures
		if (n_images>9) {
	
			for (i=10; i<=n_images; i++){
				open(temp_folder+"PPL_0" +i+ ".tif");
				//run("Split Channels");
				open(temp_folder+"FLO_0" +i+ ".tif");
				//run("Split Channels");
				open(temp_folder+"XPL_0" +i+ ".tif");
				//run("Split Channels");
				run("Images to Stack", "name=Stack" +i+ " title=[] use");
				saveAs("Tiff", temp_folder + "stack0" +i+ ".tif");
				close();
			}
		}
	}
	print("stack successfully created");
	
	//stitching
	print("stitching stacked images");
	run("Grid/Collection stitching",
	"type=[Grid: snake by rows] order=[Right & Down                ] "+
	"grid_size_x="+matrix_x+" grid_size_y="+matrix_y+" "+
	"tile_overlap=20 "+
	"first_file_index_i=1 "+
	"directory="+ temp_folder+" "+
	"file_names=stack{iii}.tif "+
	"output_textfile_name=TileConfiguration.txt "+
	"fusion_method=[Linear Blending] "+
	"regression_threshold=0.30 "+
	"max/avg_displacement_threshold=2.50 "+
	"absolute_displacement_threshold=3.50 "+
	"compute_overlap "+
	"computation_parameters=[Save computation time (but use more RAM)] "+
	"image_output=[Fuse and display]");
	
	//splitting into channels and saving
	print("splitting channels and saving stitched images");
	run("Stack to Images");
	
	for (i = 1; i <=9; i++){ 
		selectWindow("Fused-000" +i);
		run("Grays");
		run("8-bit");
		saveAs("Tiff", temp_folder + "Fused0" +i+ ".tif");
	}
	print("saving stitched PPL image");
	run("Merge Channels...", "c1=Fused01.tif c2=Fused02.tif c3=Fused03.tif create");
	run("RGB Color");
	saveAs("Tiff", folder+"final/PPL.tif");
	close();
	close();
	print("saving stitched FLO image");
	run("Merge Channels...", "c1=Fused04.tif c2=Fused05.tif c3=Fused06.tif create");
	run("RGB Color");
	saveAs("Tiff", folder+"final/FLO.tif");
	close();
	close();
	print("saving stitched XPL image");
	run("Merge Channels...", "c1=Fused07.tif c2=Fused08.tif c3=Fused09.tif create");
	run("RGB Color");
	saveAs("Tiff", folder+"final/XPL.tif");
	close();
	close();
	
	// Delete the files and the directory
	list = getFileList(temp_folder);
	for (i=0; i<list.length; i++)
	  ok = File.delete(temp_folder+list[i]);
	ok = File.delete(temp_folder);
	if (File.exists(temp_folder))
	  exit("Unable to delete directory");
	else
	  print("Directory and files successfully deleted");  
	print("Command successfully finished!");
}
print("End of macro");
      
       
        
          

