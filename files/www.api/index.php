<?php
$a = file_get_contents("https://api.icndb.com/jokes/random?exclude=explicit");
$b = json_decode($a, true);
$c = $b['joke'];
echo "<pre>";
print_r($b);
echo "</pre>";
?>