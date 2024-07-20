local Array2D = {} :: Array2DImpl & { new: <T>(width: number, height: number, defaultValue: T?) -> Array2D<T> }
Array2D.__index = Array2D

function Array2D.new<T>(width: number, height: number, defaultValue: T?): Array2D<T>
	local array = table.create(width * height, defaultValue)
	return setmetatable({
		_width = width,
		_height = height,
		Array = array,
	}, Array2D) :: Array2D<T>
end

function Array2D:Get<T>(x: number, y: number): T
	return self.Array[(y - 1) * self._width + x]
end

function Array2D:Set<T>(x: number, y: number, value: T)
	self.Array[(y - 1) * self._width + x] = value
end

function Array2D:To2D(i): (number, number)
	local x = (i - 1) % self._width + 1
	local y = math.floor((i - 1) / self._width + 1)
	return x, y
end

type Array2DImpl = {
	Get: <T>(self: _Array2D<T>, x: number, y: number) -> T,
	Set: <T>(self: _Array2D<T>, x: number, y: number, value: T) -> (),
	To2D: <T>(self: _Array2D<T>, i: number) -> (number, number),
	__index: Array2DImpl,
}
type _Array2D<T> = { _width: number, _height: number, Array: { T } }
export type Array2D<T> = _Array2D<T> & typeof(setmetatable({}, {} :: Array2DImpl))

return Array2D
