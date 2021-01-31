<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

function clean($string) {
   $string = str_replace(' ', '-', $string); // Replaces all spaces with hyphens.
   return preg_replace('/[^A-Za-z0-9\-]/', '', $string); // Removes special chars.
}

function saveData($dir, $contents){
        $parts = explode('/', $dir);
        $file = array_pop($parts);
        $dir = '';
        foreach($parts as $part)
            if(!is_dir($dir .= "/$part")) mkdir($dir);
        file_put_contents("$dir/$file", $contents);
    }

function bogonASN($string){
	$bogonArray = array(
						"0",
						"23456",
						"64496",
						"64497",
						"64498",
						"64499",
						"64500",
						"64501",
						"64502",
						"64503",
						"64504",
						"64505",
						"64507",
						"64508",
						"64509",
						"64510",
						"64511",
						"64512",
						"64513",
						"64514",
						"64515",
						"64516",
						"64517",
						"64518",
						"64519",
						"64520",
						"64521", 
						"64522", 
						"64523", 
						"64524", 
						"64525", 
						"64526", 
						"64527", 
						"64528", 
						"64529", 
						"64530", 
						"64531", 
						"64532", 
						"64533", 
						"64534", 
						"65535", 
	);
	
	if(in_array($string, $bogonArray)){
		$ret = false;
	}else{
		$ret = true;
	}
	
	return $ret;
}

$ipv4 = false;
$ipv6 = false;

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
$a = array("sessionName" => "RouteIX Networks Ltd.",
			"sessionEmail" => "connect@routeix.net",
			"ASN" => "AS123456",
			"AS-SET" => "AS-ROUTEIX",
			"sessionAddress" => array("IPv4" => "10.10.6.6", "IPv6" => "2a0a:6040:d6::6"),
			"sessionStack" => "10");
			//print_r(json_encode($a));
if($apiUser){
	if(!isset($_REQUEST['string'])){ die(json_encode(array("Error" => "Invalid Request String"))); }
		$bDecode = base64_decode($_REQUEST['string']);
		$jDecode = json_decode($bDecode, true);

		if(!isset($jDecode['sessionName'])){ die(json_encode(array("Error" => "Invalid String Details"))); }
		if(!isset($jDecode['sessionEmail'])){ die(json_encode(array("Error" => "Invalid String Details"))); }
		if(!isset($jDecode['ASN'])){ die(json_encode(array("Error" => "Invalid String Details"))); }
		if(!isset($jDecode['sessionAddress'])){ die(json_encode(array("Error" => "Invalid String Details"))); }
		if(!isset($jDecode['sessionStack'])){ die(json_encode(array("Error" => "Invalid String Details"))); }
		if(strlen($jDecode['sessionName']) < 4 || strlen($jDecode['sessionName']) > 50){ die(json_encode(array("Error" => "Invalid Session Name"))); }
		if(isset($jDecode['AS-SET'])){
		if(strlen($jDecode['AS-SET']) < 3 || strlen($jDecode['AS-SET']) > 30){ die(json_encode(array("Error" => "Invalid AS-SET"))); }
		
		$jArray['sessionName'] = clean($jDecode['sessionName']);
		if (filter_var($jDecode['sessionEmail'], FILTER_VALIDATE_EMAIL)) {
			$jArray['sessionEmail'] = $jDecode['sessionEmail'];
		} else {
			die(json_encode(array("Error" => "Invalid Session Email")));
		}
		if(!bogonASN($jDecode['ASN'])){
			die(json_encode(array("Error" => "Invalid ASN")));
		}else{
			if(is_numeric(str_replace("AS", "", $jDecode['ASN']))){
			$jArray['ASN'] = str_replace("AS", "", $jDecode['ASN']);
			}else{
				die(json_encode(array("Error" => "Invalid ASN")));
			}
		}
		if(!is_numeric($jDecode['sessionStack'])){
			die(json_encode(array("Error" => "Invalid Session Stack")));
		}elseif($jDecode['sessionStack'] == 4){
			if (filter_var($jDecode['sessionAddress']['IPv4'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
				$jArray['IPv4'] = $jDecode['sessionAddress']['IPv4'];
			}else{
				die(json_encode(array("Error" => "Invalid IPv4 Neighbor")));
			}
		}elseif($jDecode['sessionStack'] == 6){
			if (filter_var($jDecode['sessionAddress']['IPv6'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)) {
				$jArray['IPv6'] = $jDecode['sessionAddress']['IPv6'];
			}else{
				die(json_encode(array("Error" => "Invalid IPv6 Neighbor")));
			}
		}elseif($jDecode['sessionStack'] == 10){
			if (filter_var($jDecode['sessionAddress']['IPv4'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
				$jArray['IPv4'] = $jDecode['sessionAddress']['IPv4'];
			}else{
				die(json_encode(array("Error" => "Invalid IPv4 Neighbor")));
			}
			if (filter_var($jDecode['sessionAddress']['IPv6'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)) {
				$jArray['IPv6'] = $jDecode['sessionAddress']['IPv6'];
			}else{
				die(json_encode(array("Error" => "Invalid IPv6 Neighbor")));
			}
		}else{
			die(json_encode(array("Error" => "Invalid Session Stack")));
		}
if(isset($jArray['IPv4'])){
	$v4CFG = "protocol bgp PEER_AS".$jArray['ASN']." from ix_peer
{
	neighbor	as ".$jArray['ASN'].";
	neighbor	".$jArray['IPv4'].";
	description	\"AS".$jArray['ASN']." :: ".$jArray['sessionName']." :: ".$jArray['sessionEmail']."\";
	import filter
	{
		bgp_local_pref = 100;
		if net.len <= PREFIX_MIN && net ~ PREFIX_AS".$jArray['ASN']." then accept;
		if net.len >= PREFIX_MAX then reject;
		reject;
	};

	export filter
	{
		if ((0,0,".$jArray['ASN'].")) ~ bgp_large_community then reject;
		if net.len > PREFIX_MIN then reject;
		accept;
	};
}
		
		";
		$cfgFile = "/app/public/queue/".$jArray['ASN']."/peer_v4.conf";
		if (!file_exists($cfgFile)) {  
		saveData($cfgFile, $v4CFG) or die(json_encode(array("Error" => "Failed to Create Peer_v4.conf")));
		}
		
}

if(isset($jArray['IPv6'])){
	$v6CFG = "protocol bgp PEER_AS".$jArray['ASN']." from ix_peer
{
	neighbor	as ".$jArray['ASN'].";
	neighbor	".$jArray['IPv6'].";
	description	\"AS".$jArray['ASN']." :: ".$jArray['sessionName']." :: ".$jArray['sessionEmail']."\";
	import filter
	{
		bgp_local_pref = 100;
		if net.len <= PREFIX_MIN && net ~ PREFIX_AS".$jArray['ASN']." then accept;
		if net.len >= PREFIX_MAX then reject;
		reject;
	};

	export filter
	{
		if ((0,0,".$jArray['ASN'].")) ~ bgp_large_community then reject;
		if net.len > PREFIX_MIN then reject;
		accept;
	};
}
		
		";
		$cfgFile = "/app/public/queue/".$jArray['ASN']."/peer_v6.conf";
		if (!file_exists($cfgFile)) {  
		saveData($cfgFile, $v6CFG) or die(json_encode(array("Error" => "Failed to Create Peer_v6.conf")));
		}
}
		if(isset($jArray['AS-SET'])){
		$ASFILE = "/app/public/queue/".$jArray['ASN']."/AS-SET";
		if (!file_exists($cfgFile)) {  
		saveData($cfgFile, $jArray['AS-SET']) or die(json_encode(array("Error" => "Failed to Create AS-Set")));
		}
		}
		}
			$retArray['Date'] = date("d-m-Y H-m-s");
			$retArray['Status'] = "queued";
			$retArray['ASN'] = $jArray['ASN'];
		if(file_exists("/app/public/queue/".$jArray['ASN']."/peer_v4.conf")){
			$retArray['v4Peer'] = "true";
		}else{
			$retArray['v4Peer'] = "false";
		}
		if(file_exists("/app/public/queue/".$jArray['ASN']."/peer_v6.conf")){
			$retArray['v6Peer'] = "true";
		}else{
			$retArray['v6Peer'] = "false";
		}
		if(file_exists("/app/public/queue/".$jArray['ASN']."/AS-SET")){
			$retArray['AS-SET'] = "true";
		}else{
			$retArray['AS-SET'] = "false";
		}
		print_r(json_encode($retArray, true));
}else{
	print_r(json_encode(array("Error" => "Entries Failed. Invalid Information Provided.")));
}

?>
