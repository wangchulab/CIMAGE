
<html>
<head><title>Add to CIMAGE dataset:</title>
<style>
ul{list-style: none}
a{text-decoration:none}
a:hover{color:orange; /*text-decoration:underline; font-style: italic;*/}
</style>
<SCRIPT>
function clearDefault(el){
  if(el.defaultValue==el.value) el.value=""
				  }
</SCRIPT>
</head>
<body link="3333FF" vlink="337733">
<center><font face="arial, helvetica">
<H3>Upload Status:</H3>

<DIV style="background-color: #EFEFEF; width: 600px; padding: 10px; border: grey 1px dashed;">


<?php
$iserror = 0;
$invalidfile = 0;
$dataname = $_GET["filename"] . "/" ;
if (($_FILES["file"]["size"] < 40000000))
  {
    if ($_FILES["file"]["error"] > 0)
      {
	echo "Error: " . $_FILES["file"]["error"] . "<br />";
	$iserror = 1;
      }
    else
      {
	echo "<CODE>File: " . $_FILES["file"]["name"] . "<br />";
	echo "Extension: " . strrchr($_FILES["file"]["name"], '.') . "<BR>";
	echo "Type: " . $_FILES["file"]["type"] . "<br />";
	echo "Size: " . ($_FILES["file"]["size"] / 1024) . " Kb<br />";

	if (file_exists("/srv/www/htdocs/cimage/cimage_data/". $dataname . $_FILES["file"]["name"]))
	  {

	    unlink("/srv/www/htdocs/cimage/cimage_data/" . $dataname . $_FILES["file"]["name"]);
	    move_uploaded_file($_FILES["file"]["tmp_name"], "/srv/www/htdocs/cimage/cimage_data/" . $dataname . $_FILES["file"]["name"]);
	    echo "Stored in: " . "cimage/cimage_data/" . $dataname . $_FILES["file"]["name"] . "</CODE>";
	    print ("<h3></code>Upload successful!  (old file replaced)</h3>\n");
	  }
	else
	  {
	    move_uploaded_file($_FILES["file"]["tmp_name"], "/srv/www/htdocs/cimage/cimage_data/" . $dataname . $_FILES["file"]["name"]);
   	    echo "Stored in: " . "cimage/cimage_data/" . $dataname . $_FILES["file"]["name"] . "</CODE>";
            print ("<h3></code>Upload successful!  (new file added)</h3>\n");
	  }
      }
  }
  else
    {
      echo "<h3><FONT COLOR=FF0000>Upload unsuccessful! Reason: Invalid file.</FONT></h3>\n";
      	$iserror = 1;
    }


print ("<p><p>\n");
print ("</DIV>\n");

print ("<HR WIDTH=75%><P>To view updated readme for this
	dataset, <A HREF=\"/cgi-bin/cravatt/restricted/cimage-dset-list.pl?filename=" . $dataname . "&description=\">click here</A>.");

?>

</body></html>


