// simple web service used echo framework

package main

import (
	"fmt"
	"io"
	"net/http"
	"os"

	"github.com/labstack/echo"
)

func main() {
	fmt.Println("Service A is running...")

	e := echo.New()
	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Service A")
	})

	// define route /B
	e.GET("/B", func(c echo.Context) error {
		// call service B
		resp, err := http.Get(os.Getenv("SERVICE_B_URL"))
		if err != nil {
			panic(err)
		}
		defer resp.Body.Close()

		// read response body
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			panic(err)
		}

		// return response body
		return c.String(http.StatusOK, "Service A > "+string(body))
	})

	e.Logger.Fatal(e.Start(":8080"))
}
