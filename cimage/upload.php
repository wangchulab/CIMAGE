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

</head>
<body link="3333FF" vlink="337733">
<center><font face="arial, helvetica">

<P><P><HR WIDTH=75%>
<h3>Add Dataset:</h3>
<div style="background-color: #EFEFEF; width: 600px; padding: 15px; border: grey 1px dashed;">
<A HREF="/cgi-bin/cravatt/restricted/cimage-dset-add.pl?function=list" onClick="javascript:return confirm('Are you sure you want to add data?')">Click here</a> to add datasets.
</div>
<P><BR><P>

<P><P><HR WIDTH=75%>
<h3>Remove Dataset:</h3>
<div style="background-color: #EFEFEF; width: 600px; padding: 15px; border: grey 1px dashed;">
<A HREF="/cgi-bin/cravatt/restricted/cimage-dset-remove.pl?function=list" onClick="javascript:return confirm('Are you sure you want to remove data?')">Click here</a> to remove datasets.
</div>
<P><BR><P>


<?php
$path="/srv/www/htdocs/cimage/cimage_data/";
$ar=getDirectorySize($path);

//echo "<FONT SIZE=-2 COLOR=999999>$path";
echo "<FONT SIZE=-2 COLOR=999999>";
echo "<BR>Current database size: ".sizeFormat($ar['size'])."<br>";
//echo "No. of files : ".$ar['count']."<br>";
//echo "No. of directories : ".$ar['dircount']."<br></font>";
?>



</body>
</html>


<?php
function getDirectorySize($path)
{
  $totalsize = 0;
  $totalcount = 0;
  $dircount = 0;
  if ($handle = opendir ($path))
  {
    while (false !== ($file = readdir($handle)))
      {
	$nextpath = $path . '/' . $file;
	if ($file != '.' && $file != '..' && !is_link ($nextpath))
	  {
	    if (is_dir ($nextpath))
	      {
		$dircount++;
		$result = getDirectorySize($nextpath);
		$totalsize += $result['size'];
		$totalcount += $result['count'];
		$dircount += $result['dircount'];
	      }
	    elseif (is_file ($nextpath))
	      {
		$totalsize += filesize ($nextpath);
		$totalcount++;
	      }
	  }
      }
  }
  closedir ($handle);
  $total['size'] = $totalsize;
  $total['count'] = $totalcount;
  $total['dircount'] = $dircount;
  return $total;
}

function sizeFormat($size)
{
  if($size<1024)
    {
      return $size." bytes";
    }
  else if($size<(1024*1024))
    {
      $size=round($size/1024,1);
      return $size." KB";
    }
  else if($size<(1024*1024*1024))
    {
      $size=round($size/(1024*1024),1);
      return $size." MB";
    }
  else
    {
      $size=round($size/(1024*1024*1024),1);
      return $size." GB";
    }

}
?>
