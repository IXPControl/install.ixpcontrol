<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
function clean($string) {
   $string = str_replace(' ', '-', $string); // Replaces all spaces with hyphens.
   return preg_replace('/[^A-Za-z0-9\-]/', '', $string); // Removes special chars.
}

if(!isset($_REQUEST['apiKey'])){
	die(json_encode(array("Error" => "Not Authorized")));
}

if(isset($_REQUEST['apiKey'])){
	if(strlen($_REQUEST['apiKey']) != 36){
		$apiUser = false;
		die(json_encode(array("Error" => "Not Authorized")));
	}
	$apiString = file_get_contents("../key/api.key");
	if($_REQUEST['apiKey'] == $apiString){
		$apiUser = true;
	}
}

if($apiUser){
	if(!isset($_REQUEST['string'])){ die(json_encode(array("Error" => "Invalid Request String"))); }
		$bDecode = base64_decode($_REQUEST['string']);
		$jDecode = json_decode($bDecode, true);
	if(!isset($jDecode['ASN'])){ die(json_encode(array("Error" => "Invalid String Details"))); }
		$jDecode['ASN'] = str_replace("AS", "", $jDecode['ASN']);
	if(!is_numeric($jDecode['ASN'])){ die(json_encode(array("Error" => "Invalid ASN Supplied"))); }
	
			$response["ASN"] = $jDecode['ASN'];
			
		if(file_exists("/app/private/PEERS/".$jDecode['ASN']."/peer_v4.conf")){
			$response["IPv4"]["STATUS"] = system("docker exec RouteServer birdc show proto | grep 'PEER_AS".$jDecode['ASN']."' | awk '{print $6}'", $ret);
			$response["IPv4"]["BIRD"] = system("docker exec RouteServer birdc show proto all PEER_AS".$jDecode['ASN']."", $ret);
		}
		if(file_exists("/app/private/PEERS/".$jDecode['ASN']."/prefix_v4.conf") && file_exists("/app/private/PEERS/".$jDecode['ASN']."/peer_v4.conf")){
			$response["IPv4"]["PREFIX"] = file_get_contents("/app/private/PEERS/".$jDecode['ASN']."/prefix_v4.conf");
		}else{
			$response["IPv4"]["STATUS"] = "INACTIVE";
			$response["IPv4"]["BIRD"] = "NULL";
			$response["IPv4"]["PREFIX"] = "NULL";
		}
		if(file_exists("/app/private/PEERS/".$jDecode['ASN']."/peer_v6.conf")){
			$response["IPv6"]["STATUS"] = system("docker exec RouteServer birdc6 show proto | grep 'PEER_AS".$jDecode['ASN']."' | awk '{print $6}'", $ret);
			$response["IPv6"]["BIRD"] = system("docker exec RouteServer birdc6 show proto all PEER_AS".$jDecode['ASN']."", $ret);
		}
		if(file_exists("/app/private/PEERS/".$jDecode['ASN']."/prefix_v6.conf") && file_exists("/app/private/PEERS/".$jDecode['ASN']."/peer_v6.conf")){
			$response["IPv6"]["PREFIX"] = file_get_contents("/app/private/PEERS/".$jDecode['ASN']."/prefix_v6.conf");
		}else{
			$response["IPv6"]["STATUS"] = "INACTIVE";
			$response["IPv6"]["BIRD"] = "INACTIVE";
			$response["IPv6"]["PREFIX"] = "NULL";
		}
		
		print_r(json_encode($response));
}
	
	
	

?>

