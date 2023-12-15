// simple web service used echo framework

package main

import (
	"io"
	"net/http"
	"os"

	"github.com/labstack/echo"
)

func main() {
	// create echo instance
	e := echo.New()

	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Service B")
	})

	// define route /A
	e.GET("/A", func(c echo.Context) error {
		// call service A
		resp, err := http.Get(os.Getenv("SERVICE_A_URL"))
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
		return c.String(http.StatusOK, "Service B > "+string(body))
	})

	// start echo server
	e.Logger.Fatal(e.Start(":8081"))
}
