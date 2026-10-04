for (var i = 0; i < array_length(points) - 1; i++) {
	var _x1 = points[i][0];		var _y1 = points[i][1];
	var _x2 = points[i + 1][0];	var _y2 = points[i + 1][1];	
	//var _mx = (_x1 + _x2) / 2 + random_range(-6, 6);
	//var _my = (_y1 + _y2) / 2 + random_range(-6, 6);
	scr_draw_lightning(_x1, _y1, _x2, _y2, i * 17, element_color);
}