<html>
<head><title>Cravatt-lab CIMAGE Database [temporary upload]</title>
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

</head>2
<body link="3333FF" vlink="337733">
<center><font face="arial, helvetica">
<BR><P><H3>Add or Change a detailed description readme file:</H3>
<div style="background-color: #EFEFEF; width: 600px; padding: 15px; border: grey 1px dashed;">
<h3>Select file from your computer, here:</h3>
Valid files are <code>readme.txt</code> files <p>

<?php
$filename=$_GET["filename"];
?>

<form action="upload_file.php?filename=<?php echo $filename?>" method="post" enctype="multipart/form-data">

<label for="file">Filename:</label>
<input type="file" name="file" id="file" SIZE=40><P>
<FONT COLOR="FF0000">No spaces in the filename!</FONT><P>
The file must be plain-text, and less than 40 megabytes.
<input type="submit" name="submit" value="Submit">
</form>
</div>

